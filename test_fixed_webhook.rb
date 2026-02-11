#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing fixed webhook processing..."

# Simulate the exact subscription event structure from Paddle
event = {
  "event_type" => "subscription.created",
  "data" => {
    "id" => "sub_test_fixed_" + SecureRandom.hex(8),
    "customer_id" => "ctm_01kh79ctvng65dwpbqwz135yjy",  # This is the key fix!
    "status" => "active",
    "items" => [{
      "price_id" => "pri_01kh7aq09r0kyg8dvgwp6bk0dz"
    }],
    "next_billed_at" => (Time.now + 1.month).iso8601
  }
}

puts "Simulating subscription event with correct structure..."
puts "Customer ID: #{event['data']['customer_id']}"
puts "Subscription ID: #{event['data']['id']}"

# Test the method directly
begin
  controller = Object.new
  controller.extend(Webhooks::PaddleController)
  
  # Mock Rails logger
  def controller.logger
    @logger ||= Logger.new(STDOUT)
  end
  
  puts "\nCalling handle_subscription_event..."
  controller.send(:handle_subscription_event, event)
  puts "✅ Webhook processing successful!"
  
  # Check the result
  profile = Profile.find_by(paddle_customer_id: event['data']['customer_id'])
  if profile
    puts "\nProfile updated:"
    puts "  Email: #{profile.email}"
    puts "  Plan: #{profile.plan}"
    puts "  Subscription ID: #{profile.paddle_subscription_id}"
    puts "  Status: #{profile.paddle_subscription_status}"
    puts "  Next Bill: #{profile.paddle_next_bill_at}"
  else
    puts "❌ Profile not found"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
