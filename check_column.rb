#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Checking if paddle_customer_id column exists..."
result = ActiveRecord::Base.connection.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'paddle_customer_id'")
puts "Rows found: #{result.count}"

if result.count > 0
  puts "Column exists!"
else
  puts "Column does not exist. Adding it..."
  ActiveRecord::Base.connection.execute("ALTER TABLE profiles ADD COLUMN paddle_customer_id VARCHAR")
  puts "Column added!"
end

# Reload the model
Profile.reset_column_information

# Test again
puts "Testing profile access..."
profile = Profile.find_by(email: 'jo@example.com')
if profile
  puts "Profile found: #{profile.id}"
  puts "Paddle customer ID: #{profile.paddle_customer_id || 'nil'}"
end
