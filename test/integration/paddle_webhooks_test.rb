require "test_helper"
require "json"
require "openssl"

class PaddleWebhooksTest < ActionDispatch::IntegrationTest
  test "duplicate webhook deliveries are acknowledged once without reprocessing" do
    user = create_user(email: "paddle-dup@example.com")
    payload = {
      event_id: "evt_duplicate_123",
      event_type: "transaction.completed",
      occurred_at: Time.current.iso8601,
      data: {
        id: "txn_123",
        status: "completed",
        customer_id: "ctm_123",
        customer: { email: user.email },
        customer_email: user.email,
        subscription_id: "sub_123",
        items: [ { price_id: "pri_123" } ],
        custom_data: { user_id: user.id }
      }
    }

    with_paddle_webhook_env do
      body = JSON.generate(payload)
      headers = signed_paddle_headers(body)

      assert_difference -> { UsageEvent.where(event_type: UsageEvent::PADDLE_WEBHOOK_EVENT).count }, 1 do
        post webhooks_paddle_path, params: body, headers: headers
      end
      assert_response :success

      profile = user.profile.reload
      assert_equal "paid", profile.plan
      assert_equal "sub_123", profile.paddle_subscription_id
      assert_equal "pri_123", profile.paddle_price_id

      assert_no_difference -> { UsageEvent.where(event_type: UsageEvent::PADDLE_WEBHOOK_EVENT).count } do
        post webhooks_paddle_path, params: body, headers: headers
      end
      assert_response :success

      receipt = UsageEvent.find_by(event_type: UsageEvent::PADDLE_WEBHOOK_EVENT, session_id: "evt_duplicate_123")
      assert_not_nil receipt
      assert_equal Digest::SHA256.hexdigest(body), receipt.data_hash
    end
  end

  test "transaction webhook stores nested item price id shape" do
    user = create_user(email: "paddle-nested-price@example.com")
    payload = {
      event_id: "evt_nested_price_123",
      event_type: "transaction.completed",
      occurred_at: Time.current.iso8601,
      data: {
        id: "txn_nested_123",
        status: "completed",
        customer_id: "ctm_nested_123",
        customer: { email: user.email },
        customer_email: user.email,
        subscription_id: "sub_nested_123",
        items: [ { price: { id: "pri_nested_123" } } ],
        custom_data: { user_id: user.id }
      }
    }

    with_paddle_webhook_env do
      body = JSON.generate(payload)
      headers = signed_paddle_headers(body)

      post webhooks_paddle_path, params: body, headers: headers

      assert_response :success
      profile = user.profile.reload
      assert_equal "pri_nested_123", profile.paddle_price_id
      assert_equal "sub_nested_123", profile.paddle_subscription_id
      assert_equal "paid", profile.plan
    end
  end

  test "stale signed webhook is rejected" do
    payload = {
      event_id: "evt_old_123",
      event_type: "transaction.completed",
      occurred_at: 20.minutes.ago.iso8601,
      data: {
        id: "txn_old_123"
      }
    }

    with_paddle_webhook_env do
      body = JSON.generate(payload)
      stale_ts = 10.minutes.ago.to_i
      headers = signed_paddle_headers(body, ts: stale_ts)

      assert_no_difference -> { UsageEvent.where(event_type: UsageEvent::PADDLE_WEBHOOK_EVENT).count } do
        post webhooks_paddle_path, params: body, headers: headers
      end

      assert_response :unauthorized
    end
  end

  private

  def create_user(email:)
    password = "password123"
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current,
      name: email.split("@").first
    )

    Profile.create!(
      user: user,
      plan: "free",
      business_name: "Biz #{email}",
      phone: "123456789",
      email: email,
      address: "123 Main St",
      hourly_rate: 100,
      tax_rate: 18,
      currency: "USD",
      billing_mode: "hourly",
      tax_scope: "labor,products_only"
    )

    user.reload
  end

  def with_paddle_webhook_env
    previous = {
      "PADDLE_WEBHOOK_SECRET" => ENV["PADDLE_WEBHOOK_SECRET"],
      "PADDLE_WEBHOOK_TOLERANCE_SECONDS" => ENV["PADDLE_WEBHOOK_TOLERANCE_SECONDS"]
    }

    ENV["PADDLE_WEBHOOK_SECRET"] = "test_webhook_secret"
    ENV["PADDLE_WEBHOOK_TOLERANCE_SECONDS"] = "300"
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def signed_paddle_headers(body, ts: Time.current.to_i)
    digest = OpenSSL::Digest.new("sha256")
    h1 = OpenSSL::HMAC.hexdigest(digest, ENV.fetch("PADDLE_WEBHOOK_SECRET"), "#{ts}:#{body}")

    {
      "CONTENT_TYPE" => "application/json",
      "Paddle-Signature" => "ts=#{ts};h1=#{h1}"
    }
  end
end
