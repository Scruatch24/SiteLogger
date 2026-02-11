#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing webhook processing..."

# Find the existing profile
profile = Profile.find_by(email: 'jo@example.com')
if profile
  puts "Found profile: #{profile.email} (ID: #{profile.id})"
  puts "Current plan: #{profile.plan}"
  puts "Current subscription ID: #{profile.paddle_subscription_id}"
  
  # Simulate updating the subscription with a new ID
  new_subscription_id = "sub_test_" + SecureRandom.hex(8)
  new_next_bill = Time.now + 1.month
  
  puts "\nSimulating webhook update..."
  puts "New subscription ID: #{new_subscription_id}"
  
  # Update the profile like the webhook would
  profile.update_columns(
    paddle_subscription_id: new_subscription_id,
    paddle_subscription_status: 'active',
    paddle_price_id: 'pri_01kh7aq09r0kyg8dvgwp6bk0dz',
    paddle_next_bill_at: new_next_bill
  )
  
  puts "✅ Update successful!"
  puts "Updated subscription ID: #{profile.paddle_subscription_id}"
  puts "Next billing: #{profile.paddle_next_bill_at}"
  
  # Reset back to original
  profile.update_columns(
    paddle_subscription_id: 'sub_01kh7c63petzrvck8a9dvptxct',
    paddle_next_bill_at: '2026-03-11 22:12:12 UTC'
  )
  puts "\n✅ Reset to original values"
  
else
  puts "❌ Profile not found"
end
