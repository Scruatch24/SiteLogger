require 'zoho_zeptomail-ruby'

begin
  client = ZohoZeptoMail::Client.new(api_key: nil, region: 'EU')
rescue => e
  puts "Caught error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end

begin
  client = ZohoZeptoMail::Client.new(api_key: 'test', region: 'EU')
  puts "Client created successfully"
rescue => e
  puts "Caught error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end
