#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Cleaning up incorrect subscription assignments..."

# Find profiles with the wrong subscription data
wrong_profiles = Profile.where(paddle_subscription_id: 'sub_01kh7cdr10qredafmbhkga0e0v')
puts "Found #{wrong_profiles.count} profiles with wrong subscription ID"

wrong_profiles.each do |profile|
  puts "Profile #{profile.id} (#{profile.email}): plan=#{profile.plan}, sub_id=#{profile.paddle_subscription_id}"
  
  # Only reset if this isn't the jo@example.com profile (which should keep its subscription)
  if profile.email != 'jo@example.com'
    profile.update_columns(
      plan: 'free',
      paddle_subscription_id: nil,
      paddle_subscription_status: nil,
      paddle_price_id: nil,
      paddle_customer_id: nil,
      paddle_next_bill_at: nil
    )
    puts "  -> Reset to free plan"
  else
    puts "  -> Kept (correct profile)"
  end
end

puts "Cleanup complete!"
