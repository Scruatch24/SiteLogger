# frozen_string_literal: true

require "resend"

if ENV["RESEND_API_KEY"].present?
  Resend.api_key = ENV["RESEND_API_KEY"]
  
  # Ensure ActionMailer is also configured globally in case environment config isn't enough
  ActionMailer::Base.resend_settings = {
    api_key: ENV["RESEND_API_KEY"]
  }
end
