# frozen_string_literal: true

class Webhooks::PaddleController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_signature!

  def receive
    event = JSON.parse(request.raw_post)

    case event["event_type"]
    when "customer.created"
      handle_customer_created(event)
    when "transaction.completed"
      handle_transaction_completed(event)
    when "transaction.created", "transaction.ready", "transaction.paid", "transaction.updated"
      # These events are intermediate states, we only care about completed transactions
      Rails.logger.info("Paddle transaction event: #{event['event_type']} - status: #{event.dig('data', 'status')}")
    when "subscription.created", "subscription.activated", "subscription.updated"
      handle_subscription_event(event)
    when "subscription.canceled", "subscription.paused"
      handle_subscription_status_change(event)
    when "address.created", "payment_method.saved"
      # These are supporting events, log but don't process
      Rails.logger.info("Paddle supporting event: #{event['event_type']}")
    else
      Rails.logger.info("Unhandled Paddle event: #{event['event_type']}")
    end

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.warn("Paddle webhook JSON parse error: #{e.message}")
    head :bad_request
  end

  private

  def handle_transaction_completed(event)
    data = event["data"] || {}
    customer = data["customer"] || {}
    email = customer["email"] || resolve_customer_email(customer["id"])
    customer_id = customer["id"]
    price_id = (data["items"]&.first || {})["price_id"]

    profile = find_profile(email)
    return unless profile

    profile.update_columns(
      plan: "paid",
      paddle_price_id: price_id,
      paddle_customer_email: email,
      paddle_customer_id: customer_id,
      paddle_subscription_status: "active"
    )
  end

  def handle_subscription_event(event)
    data = event["data"] || {}
    customer_id = data["customer_id"]  # Customer ID is directly in data, not in customer object
    subscription_id = data["id"]
    status = data["status"]
    price_id = (data["items"]&.first || {})["price_id"]
    next_billing_time = data["next_billed_at"]

    Rails.logger.info "Paddle subscription event: customer_id=#{customer_id.inspect}, subscription_id=#{subscription_id.inspect}"

    # First try to find profile by customer_id (more efficient)
    profile = Profile.find_by(paddle_customer_id: customer_id)
    
    # If not found, try to resolve email and find by email
    unless profile
      # For subscription events, we need to get the customer email via API since it's not in the event
      email = resolve_customer_email(customer_id)
      profile = find_profile(email)
    end
    
    return unless profile

    Rails.logger.info "Paddle subscription event: found profile #{profile.id}, updating plan to paid"

    profile.update_columns(
      plan: "paid",
      paddle_subscription_id: subscription_id,
      paddle_subscription_status: status,
      paddle_price_id: price_id,
      paddle_customer_id: customer_id,
      paddle_next_bill_at: next_billing_time
    )
  end

  def handle_subscription_status_change(event)
    data = event["data"] || {}
    customer_id = data["customer_id"]  # Customer ID is directly in data
    status = data["status"]
    subscription_id = data["id"]

    # First try to find profile by customer_id (more efficient)
    profile = Profile.find_by(paddle_customer_id: customer_id)
    
    # If not found, try to resolve email and find by email
    unless profile
      email = resolve_customer_email(customer_id)
      profile = find_profile(email)
    end
    
    return unless profile

    profile.update_columns(
      paddle_subscription_id: subscription_id,
      paddle_subscription_status: status,
      paddle_customer_id: customer_id,
      plan: status == "canceled" ? "free" : profile.plan
    )
  end

  def handle_customer_created(event)
    data = event["data"] || {}
    email = data["email"]
    customer_id = data["id"]

    profile = find_profile(email)
    return unless profile

    profile.update_columns(
      paddle_customer_email: email,
      paddle_customer_id: customer_id
    )
  end

  def find_profile(email)
    return nil if email.blank?

    Profile.find_by(email: email) || Profile.joins(:user).find_by(users: { email: email })
  end

  def resolve_customer_email(customer_id)
    return nil if customer_id.blank?
    api_key = ENV["PADDLE_API_KEY"]
    return nil if api_key.blank?

    require "net/http"
    require "json"
    base_url = Rails.env.production? ? "https://api.paddle.com" : "https://sandbox-api.paddle.com"
    uri = URI("#{base_url}/customers/#{customer_id}")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 5
    http.open_timeout = 5

    resp = http.request(req)
    return nil unless resp.is_a?(Net::HTTPSuccess)

    body = JSON.parse(resp.body) rescue nil
    body&.dig("data", "email")
  rescue StandardError => e
    Rails.logger.warn("Paddle resolve_customer_email failed: #{e.message}")
    nil
  end

  def verify_signature!
    raw = request.raw_post
    signature = request.headers["Paddle-Signature"]
    secret = ENV["PADDLE_WEBHOOK_SECRET"]

    unless secret.present? && signature.present?
      Rails.logger.warn("Paddle webhook missing secret or signature header")
      return head :unauthorized
    end

    verifier = Paddle::WebhookVerifier.new(secret: secret)
    unless verifier.valid?(raw_body: raw, signature: signature)
      Rails.logger.warn("Paddle webhook signature invalid; provided=#{signature.inspect}")
      return head :unauthorized
    end
  end
end
