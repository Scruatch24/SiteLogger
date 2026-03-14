# frozen_string_literal: true

require "digest"

class Webhooks::PaddleController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_signature!

  def receive
    raw_body = request.raw_post
    event = JSON.parse(raw_body)

    status = UsageEvent.process_paddle_webhook_once!(
      external_id: webhook_dedupe_key(event, raw_body),
      payload_hash: Digest::SHA256.hexdigest(raw_body),
      ip_address: request.remote_ip
    ) do
      dispatch_event(event)
    end

    Rails.logger.info("Paddle webhook duplicate ignored: #{webhook_dedupe_key(event, raw_body)}") if status == :duplicate

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.warn("Paddle webhook JSON parse error: #{e.message}")
    head :bad_request
  end

  private

  def dispatch_event(event)
    case event["event_type"]
    when "customer.created"
      handle_customer_created(event)
    when "transaction.completed", "transaction.paid"
      handle_transaction_completed(event)
    when "transaction.created", "transaction.ready", "transaction.updated"
      # These events are intermediate states, we only care about paid/completed transactions
      Rails.logger.info("Paddle transaction event: #{event['event_type']} - status: #{event.dig('data', 'status')}")
    when "subscription.created", "subscription.activated", "subscription.updated"
      handle_subscription_event(event)
    when "subscription.canceled", "subscription.paused"
      handle_subscription_status_change(event)
    when "transaction.payment_failed"
      handle_payment_failed(event)
    when "address.created", "payment_method.saved"
      # These are supporting events, log but don't process
      Rails.logger.info("Paddle supporting event: #{event['event_type']}")
    else
      Rails.logger.info("Unhandled Paddle event: #{event['event_type']}")
    end
  end

  def handle_transaction_completed(event)
    data = event["data"] || {}
    customer = data["customer"] || {}
    customer_id = data["customer_id"].presence || customer["id"].presence
    email = customer["email"].presence || data["customer_email"].presence
    first_item = (data["items"] || []).first || {}
    price_id = first_item["price_id"].presence || first_item.dig("price", "id")
    subscription_id = data["subscription_id"]

    profile = find_profile_for_event(
      customer_id: customer_id,
      email: email,
      custom_data: data["custom_data"]
    )

    if profile.nil?
      Rails.logger.warn("Paddle transaction event: no matching profile found (customer_id=#{customer_id.inspect}, email=#{email.inspect})")
      return
    end

    effective_email = email.presence || profile.email.presence || profile.user&.email

    update_attrs = {
      plan: "paid",
      paddle_price_id: price_id,
      paddle_customer_email: effective_email,
      paddle_subscription_status: "active"
    }
    if profile.has_attribute?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end
    update_attrs[:paddle_subscription_id] = subscription_id if subscription_id.present?

    profile.update_columns(update_attrs)

    if profile.user.present?
      user = profile.user
      amount = data.dig("details", "totals", "grand_total").to_f / 100.0 rescue 0
      currency = data.dig("currency_code").presence || profile.currency.presence || "USD"
      UserMailer.payment_receipt(
        user,
        amount: amount,
        currency: currency,
        transaction_id: data["id"].to_s,
        plan_name: "Pro"
      ).deliver_later
    end
  end

  def handle_subscription_event(event)
    data = event["data"] || {}
    customer_id = data["customer_id"].presence || data.dig("customer", "id")
    subscription_id = data["id"]
    status = data["status"]
    first_item = (data["items"] || []).first || {}
    price_id = first_item["price_id"].presence || first_item.dig("price", "id")
    next_billing_time = data["next_billed_at"]

    Rails.logger.info "Paddle subscription event: customer_id=#{customer_id.inspect}, subscription_id=#{subscription_id.inspect}"

    profile = find_profile_for_event(
      customer_id: customer_id,
      email: nil,
      custom_data: data["custom_data"]
    )

    unless profile
      Rails.logger.warn("Paddle subscription event: no matching profile found (customer_id=#{customer_id.inspect}, subscription_id=#{subscription_id.inspect})")
      return
    end

    Rails.logger.info "Paddle subscription event: found profile #{profile.id}, updating plan to paid"

    # Detect scheduled cancellation (user canceled via billing portal but period hasn't ended)
    scheduled_change = data["scheduled_change"]
    scheduled_cancel = scheduled_change.is_a?(Hash) && scheduled_change["action"] == "cancel"
    cancel_effective_at = scheduled_cancel ? parse_paddle_time(scheduled_change["effective_at"]) : nil

    # For subscription.updated: only downgrade if truly canceled with no future access
    resolved_plan = if %w[canceled paused].include?(status.to_s)
      ends_at = parse_paddle_time(data["ends_at"] || data["current_billing_period"]&.dig("ends_at"))
      (ends_at.present? && ends_at > Time.current) ? "paid" : "free"
    else
      "paid"
    end

    # If there's a scheduled cancellation, mark status as canceled even though Paddle says "active"
    effective_status = scheduled_cancel ? "canceled" : status

    update_attrs = {
      plan: resolved_plan,
      paddle_subscription_id: subscription_id,
      paddle_subscription_status: effective_status,
      paddle_price_id: price_id,
      paddle_next_bill_at: next_billing_time
    }
    if cancel_effective_at.present? && profile.has_attribute?(:paddle_cancelled_at)
      update_attrs[:paddle_cancelled_at] = cancel_effective_at
    elsif !scheduled_cancel && profile.has_attribute?(:paddle_cancelled_at) && profile.paddle_cancelled_at.present?
      update_attrs[:paddle_cancelled_at] = nil
    end
    if profile.has_attribute?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end

    profile.update_columns(update_attrs)

    if scheduled_cancel && profile.user.present?
      ends_at = cancel_effective_at
      UserMailer.subscription_canceled(profile.user, ends_at: ends_at).deliver_later
    end
  end

  def handle_subscription_status_change(event)
    data = event["data"] || {}
    customer_id = data["customer_id"].presence || data.dig("customer", "id")
    status = data["status"]
    subscription_id = data["id"]

    profile = find_profile_for_event(
      customer_id: customer_id,
      email: nil,
      custom_data: data["custom_data"]
    )

    unless profile
      Rails.logger.warn("Paddle subscription status event: no matching profile found (customer_id=#{customer_id.inspect}, subscription_id=#{subscription_id.inspect}, status=#{status.inspect})")
      return
    end

    # Keep plan=paid if the user canceled but still has access until period ends.
    # Only downgrade to free when the billing period has actually ended.
    ends_at = parse_paddle_time(data["ends_at"] || data["current_billing_period"]&.dig("ends_at"))

    new_plan = if status == "canceled"
      (ends_at.present? && ends_at > Time.current) ? profile.plan : "free"
    elsif status == "paused"
      "free"
    else
      profile.plan
    end

    update_attrs = {
      paddle_subscription_id: subscription_id,
      paddle_subscription_status: status,
      plan: new_plan
    }
    if status == "canceled" && ends_at.present? && profile.has_attribute?(:paddle_cancelled_at)
      update_attrs[:paddle_cancelled_at] = ends_at
    end
    if profile.has_attribute?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end

    profile.update_columns(update_attrs)

    if status == "canceled" && profile.user.present?
      UserMailer.subscription_canceled(profile.user, ends_at: ends_at).deliver_later
    end
  end

  def handle_payment_failed(event)
    data = event["data"] || {}
    customer_id = data["customer_id"].presence || data.dig("customer", "id")
    email = data.dig("customer", "email").presence || data["customer_email"].presence

    profile = find_profile_for_event(
      customer_id: customer_id,
      email: email,
      custom_data: data["custom_data"]
    )
    return unless profile&.user.present?

    amount = data.dig("details", "totals", "grand_total").to_f / 100.0 rescue 0
    currency = data["currency_code"].presence || profile.currency.presence || "USD"
    next_attempt = parse_paddle_time(data.dig("payments", 0, "next_retried_at"))

    UserMailer.payment_failed(
      profile.user,
      amount: amount,
      currency: currency,
      next_attempt_at: next_attempt
    ).deliver_later
  end

  def parse_paddle_time(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue
    nil
  end

  def handle_customer_created(event)
    data = event["data"] || {}
    email = data["email"]
    customer_id = data["id"]

    profile = find_profile(email)
    return unless profile

    update_attrs = { paddle_customer_email: email }
    if profile.has_attribute?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end

    profile.update_columns(update_attrs)
  end

  def find_profile(email)
    return nil if email.blank?

    Profile.find_by(email: email) || Profile.joins(:user).find_by(users: { email: email })
  end

  def find_profile_for_event(customer_id:, email:, custom_data:)
    if customer_id.present? && Profile.column_names.include?("paddle_customer_id")
      profile = Profile.find_by(paddle_customer_id: customer_id)
      return profile if profile
    end

    profile = find_profile(email)
    return profile if profile

    custom_user_id = extract_user_id_from_custom_data(custom_data)
    profile = Profile.find_by(user_id: custom_user_id) if custom_user_id.present?
    return profile if profile

    resolved_email = resolve_customer_email(customer_id)
    find_profile(resolved_email)
  end

  def extract_user_id_from_custom_data(custom_data)
    return nil unless custom_data.is_a?(Hash)

    value = custom_data["user_id"] || custom_data[:user_id]
    return nil if value.blank?

    value.to_i
  end

  def resolve_customer_email(customer_id)
    return nil if customer_id.blank?
    api_key = ENV["PADDLE_API_KEY"]
    return nil if api_key.blank?

    require "net/http"
    require "json"
    uri = URI("#{paddle_api_base_url}/customers/#{customer_id}")
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

  def paddle_api_base_url
    paddle_env = ENV["PADDLE_ENVIRONMENT"].to_s.downcase
    use_sandbox = paddle_env == "sandbox" || (paddle_env.blank? && !Rails.env.production?)
    use_sandbox ? "https://sandbox-api.paddle.com" : "https://api.paddle.com"
  end

  def webhook_dedupe_key(event, raw_body)
    top_level_id = event["event_id"].presence || event["notification_id"].presence || event["id"].presence
    return top_level_id if top_level_id.present?

    [
      event["event_type"],
      event.dig("data", "id"),
      event["occurred_at"],
      Digest::SHA256.hexdigest(raw_body)
    ].compact.join(":")
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
    tolerance = ENV.fetch("PADDLE_WEBHOOK_TOLERANCE_SECONDS", 300).to_i
    unless verifier.valid?(raw_body: raw, signature: signature, tolerance_seconds: tolerance)
      Rails.logger.warn("Paddle webhook signature invalid; provided=#{signature.inspect}")
      return head :unauthorized
    end
  end
end
