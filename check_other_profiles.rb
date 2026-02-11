#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Checking other profiles with subscription data..."

# Find profiles with subscription data but no customer ID
problem_profiles = Profile.where.not(paddle_subscription_id: nil).where(paddle_customer_id: nil)

puts "Profiles with subscription but no customer ID:"
problem_profiles.each do |profile|
  puts "  #{profile.email}:"
  puts "    Subscription ID: #{profile.paddle_subscription_id}"
  puts "    Plan: #{profile.plan}"
  puts "    Status: #{profile.paddle_subscription_status}"
  puts "    Next Bill: #{profile.paddle_next_bill_at}"
end

puts "\nTotal: #{problem_profiles.count} problematic profiles"

# Also check profiles with customer data but no subscription
customer_only = Profile.where.not(paddle_customer_id: nil).where(paddle_subscription_id: nil)
puts "\nProfiles with customer but no subscription:"
customer_only.each do |profile|
  puts "  #{profile.email}: customer_id=#{profile.paddle_customer_id}"
end
