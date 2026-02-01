require 'zoho_zeptomail-ruby'

begin
  # This should FAIL because 'EU' is not a key
  client = ZohoZeptoMail::Client.new('test', 'EU')
rescue => e
  puts "Caught expected error: #{e.class} - #{e.message}"
end

begin
  # This should SUCCEED
  client = ZohoZeptoMail::Client.new('test', 'zeptomail.zoho.eu')
  puts "Client created successfully with zeptomail.zoho.eu"
  puts "Host region is: #{client.host_region}"
rescue => e
  puts "Caught unexpected error: #{e.class} - #{e.message}"
  puts e.backtrace.first(10)
end
