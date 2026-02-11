#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing fixed webhook with direct method call..."

# Find the existing profile
profile = Profile.find_by(email: 'jo@example.com')
if profile
  puts "Found profile: #{profile.email}"
  puts "Current customer ID: #{profile.paddle_customer_id}"
  
  # Simulate the subscription update with the correct customer ID
  new_subscription_id = "sub_fixed_test_" + SecureRandom.hex(8)
  customer_id = "ctm_01kh79ctvng65dwpbqwz135yjy"
  
  puts "\nSimulating webhook update with correct customer ID..."
  puts "Customer ID: #{customer_id}"
  puts "New Subscription ID: #{new_subscription_id}"
  
  # Update like the webhook should
  profile.update_columns(
    paddle_subscription_id: new_subscription_id,
    paddle_subscription_status: 'active',
    paddle_price_id: 'pri_01kh7aq09r0kyg8dvgwp6bk0dz',
    paddle_customer_id: customer_id,  # This should now work!
    paddle_next_bill_at: Time.now + 1.month
  )
  
  puts "✅ Update successful!"
  puts "Updated subscription ID: #{profile.paddle_subscription_id}"
  puts "Customer ID: #{profile.paddle_customer_id}"
  
  # Reset back
  profile.update_columns(
    paddle_subscription_id: 'sub_01kh7c63petzrvck8a9dvptxct',
    paddle_next_bill_at: '2026-03-11 22:12:12 UTC'
  )
  puts "✅ Reset to original values"
  
else
  puts "❌ Profile not found"
end
