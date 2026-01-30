require 'net/smtp'

# Manually testing SMTP connection to Zoho
begin
  smtp = Net::SMTP.new(ENV['SMTP_ADDRESS'], ENV['SMTP_PORT'].to_i)
  if ENV['SMTP_PORT'].to_i == 587
    smtp.enable_starttls
  else
    smtp.enable_tls
  end
  
  smtp.start(ENV['SMTP_DOMAIN'], ENV['SMTP_USERNAME'], ENV['SMTP_PASSWORD'], :login) do |s|
    puts "SUCCESS: Connected and authenticated to Zoho SMTP!"
  end
rescue Net::SMTPAuthenticationError => e
  puts "FAILED: Authentication Error. 535 means the username/password/app-password is rejected by Zoho."
  puts "Details: #{e.message}"
rescue => e
  puts "FAILED: #{e.class} - #{e.message}"
end
