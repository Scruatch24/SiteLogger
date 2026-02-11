#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Checking for jo@example.com..."
user = User.find_by(email: 'jo@example.com')
puts "User found: #{user.present?}"

if user
  puts "User ID: #{user.id}"
  profile = user.profile || Profile.find_by(email: 'jo@example.com')
  puts "Profile found: #{profile.present?}"
  
  if profile
    puts "Profile ID: #{profile.id}"
    puts "Profile email: #{profile.email}"
    puts "Plan: #{profile.plan}"
    puts "Paddle subscription ID: #{profile.paddle_subscription_id}"
    puts "Paddle customer ID: #{profile.paddle_customer_id}"
  else
    puts "Creating profile..."
    profile = Profile.create(email: 'jo@example.com', user: user)
    puts "Profile created: #{profile.persisted?}"
  end
else
  puts "Creating user and profile..."
  user = User.create(email: 'jo@example.com', password: 'test123456')
  profile = Profile.create(email: 'jo@example.com', user: user)
  puts "User created: #{user.persisted?}"
  puts "Profile created: #{profile.persisted?}"
end
