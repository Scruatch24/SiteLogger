
begin
  puts "Testing Log.next_display_number..."
  puts "Next number (guest): #{Log.next_display_number(nil)}"

  u = User.first
  if u
    puts "Next number (user #{u.id}): #{Log.next_display_number(u)}"
  else
    puts "No user found, skipping user test"
  end

  puts "Testing Log instantiation..."
  log = Log.new(client: "Test Client")
  puts "Log created. User: #{log.user.inspect}"
  puts "Display number: #{log.display_number}"

  puts "Testing InvoiceGenerator..."
  require_relative 'app/services/invoice_generator'
  profile = Profile.new(business_name: "Test Biz")
  generator = InvoiceGenerator.new(log, profile)
  generator.render
  puts "PDF generated successfully"

rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace
end
