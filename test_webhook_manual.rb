#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing webhook processing manually..."

# Simulate a subscription event like Paddle would send
event = {
  "event_type" => "subscription.updated",
  "data" => {
    "id" => "sub_test_" + SecureRandom.hex(8),
    "customer_id" => "ctm_01kh79ctvng65dwpbqwz135yjy",
    "status" => "active",
    "items" => [{
      "price_id" => "pri_01kh7aq09r0kyg8dvgwp6bk0dz"
    }],
    "next_billed_at" => (Time.now + 1.month).iso8601
  }
}

puts "Simulating subscription event..."
puts "Customer ID: #{event['data']['customer_id']}"
puts "Subscription ID: #{event['data']['id']}"

# Test the method directly
begin
  # Create a simple controller context
  controller = Object.new
  controller.extend(Webhooks::PaddleController)
  
  # Mock the Rails logger
  def controller.logger
    @logger ||= Logger.new(STDOUT)
  end
  
  controller.send(:handle_subscription_event, event)
  puts "✅ Webhook processing successful!"
  
  # Check the result
  profile = Profile.find_by(paddle_customer_id: event['data']['customer_id'])
  if profile
    puts "Profile updated:"
    puts "  Plan: #{profile.plan}"
    puts "  Subscription ID: #{profile.paddle_subscription_id}"
    puts "  Status: #{profile.paddle_subscription_status}"
  else
    puts "❌ Profile not found"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
