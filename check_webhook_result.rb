#!/usr/bin/env ruby

require_relative 'config/environment'

puts 'Checking webhook processing results...'

# Look for the profile
customer = Profile.find_by(email: 'jo@example.com')
if customer
  puts "Profile found for jo@example.com:"
  puts "  Plan: #{customer.plan}"
  puts "  Paddle Customer ID: #{customer.paddle_customer_id}"
  puts "  Paddle Subscription ID: #{customer.paddle_subscription_id}"
  puts "  Paddle Customer Email: #{customer.paddle_customer_email}"
  puts "  Paddle Subscription Status: #{customer.paddle_subscription_status}"
  puts "  Paddle Next Bill At: #{customer.paddle_next_bill_at}"
else
  puts "No profile found for jo@example.com"
end

# Check if there are any profiles with paddle data
puts "\nProfiles with Paddle data:"
profiles_with_data = Profile.where.not(paddle_subscription_id: nil).or(Profile.where.not(paddle_customer_id: nil))
puts "Found #{profiles_with_data.count} profiles with Paddle data"

profiles_with_data.each do |p|
  puts "  #{p.email}: plan=#{p.plan}, sub_id=#{p.paddle_subscription_id}, cust_id=#{p.paddle_customer_id}"
end
