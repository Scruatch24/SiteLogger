class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_FROM_ADDRESS"] || 'contact@talkinvoice.online'
  self.delivery_method = :resend
  self.resend_settings = {
    api_key: ENV["RESEND_API_KEY"]
  }
end
