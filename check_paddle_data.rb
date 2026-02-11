#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Checking Paddle data consistency..."

# Check what we have in the database
jo_profile = Profile.find_by(email: 'jo@example.com')
if jo_profile
  puts "Database data for jo@example.com:"
  puts "  Customer ID: #{jo_profile.paddle_customer_id}"
  puts "  Subscription ID: #{jo_profile.paddle_subscription_id}"
  puts "  Plan: #{jo_profile.plan}"
  puts "  Status: #{jo_profile.paddle_subscription_status}"
  
  # Check if there are other profiles with the same customer ID
  same_customer = Profile.where(paddle_customer_id: jo_profile.paddle_customer_id).where.not(id: jo_profile.id)
  if same_customer.any?
    puts "\n⚠️  Other profiles with same customer ID:"
    same_customer.each { |p| puts "  #{p.email} (ID: #{p.id})" }
  end
  
  # Check if there are other profiles with the same subscription ID
  same_subscription = Profile.where(paddle_subscription_id: jo_profile.paddle_subscription_id).where.not(id: jo_profile.id)
  if same_subscription.any?
    puts "\n⚠️  Other profiles with same subscription ID:"
    same_subscription.each { |p| puts "  #{p.email} (ID: #{p.id})" }
  end
else
  puts "❌ No profile found for jo@example.com"
end

puts "\nAll profiles with Paddle data:"
profiles_with_data = Profile.where.not(paddle_customer_id: nil).or(Profile.where.not(paddle_subscription_id: nil))
profiles_with_data.each do |p|
  puts "  #{p.email}: customer=#{p.paddle_customer_id&.truncate(20)}, subscription=#{p.paddle_subscription_id&.truncate(20)}, plan=#{p.plan}"
end
