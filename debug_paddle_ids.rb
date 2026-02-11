#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Analyzing Paddle ID patterns..."

# Get all unique customer IDs from profiles
customer_ids = Profile.where.not(paddle_customer_id: nil).pluck(:paddle_customer_id).uniq
subscription_ids = Profile.where.not(paddle_subscription_id: nil).pluck(:paddle_subscription_id).uniq

puts "Unique Customer IDs in database:"
customer_ids.each { |id| puts "  #{id}" }

puts "\nUnique Subscription IDs in database:"
subscription_ids.each { |id| puts "  #{id}" }

puts "\nChecking for ID patterns..."
customer_ids.each do |cid|
  matching_subs = Profile.where(paddle_customer_id: cid)
  puts "Customer #{cid} has #{matching_subs.count} profiles:"
  matching_subs.each { |p| puts "  - #{p.email} (sub: #{p.paddle_subscription_id})" }
end

# Check the specific jo@example.com profile
jo_profile = Profile.find_by(email: 'jo@example.com')
if jo_profile
  puts "\njo@example.com details:"
  puts "  Customer ID: #{jo_profile.paddle_customer_id}"
  puts "  Subscription ID: #{jo_profile.paddle_subscription_id}"
  puts "  Plan: #{jo_profile.plan}"
  
  # Check if this customer ID appears in other profiles
  others = Profile.where(paddle_customer_id: jo_profile.paddle_customer_id).where.not(email: 'jo@example.com')
  if others.any?
    puts "  ⚠️  Same customer ID in other profiles:"
    others.each { |p| puts "    - #{p.email}" }
  end
end
