#!/usr/bin/env ruby

require_relative 'config/environment'

customer_id = 'ctm_01kh79ctvng65dwpbqwz135yjy'
subscription_id = 'sub_01kh7c63petzrvck8a9dvptxct'

puts "Testing subscription update..."

profile = Profile.find_by(paddle_customer_id: customer_id)
if profile
  puts "Found profile by customer_id!"
  puts "Before: plan=#{profile.plan}, sub_id=#{profile.paddle_subscription_id}"
  
  profile.update_columns(
    plan: 'paid',
    paddle_subscription_id: subscription_id,
    paddle_subscription_status: 'active',
    paddle_price_id: 'pri_01kh7aq09r0kyg8dvgwp6bk0dz',
    paddle_next_bill_at: '2026-03-11T22:12:12.110737Z'
  )
  
  puts "After: plan=#{profile.plan}, sub_id=#{profile.paddle_subscription_id}"
  puts "Status: #{profile.paddle_subscription_status}"
  puts "Next bill: #{profile.paddle_next_bill_at}"
else
  puts "Profile not found"
end
