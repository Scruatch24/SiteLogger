#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Cleaning up incorrect subscription assignments..."

# Reset the problematic profiles
problem_profiles = Profile.where.not(paddle_subscription_id: nil).where(paddle_customer_id: nil)

problem_profiles.each do |profile|
  puts "Resetting #{profile.email}:"
  puts "  From: plan=#{profile.plan}, sub_id=#{profile.paddle_subscription_id}"
  
  profile.update_columns(
    plan: 'free',
    paddle_subscription_id: nil,
    paddle_subscription_status: nil,
    paddle_price_id: nil,
    paddle_next_bill_at: nil
  )
  
  puts "  To: plan=#{profile.plan}, sub_id=#{profile.paddle_subscription_id}"
end

puts "\n✅ Cleanup complete!"
puts "\nCurrent status:"
puts "jo@example.com: plan=#{Profile.find_by(email: 'jo@example.com').plan}, sub_id=#{Profile.find_by(email: 'jo@example.com').paddle_subscription_id}"
