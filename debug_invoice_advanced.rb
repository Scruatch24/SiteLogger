
begin
  puts "Start advanced debug..."

  # 1. Test Log.next_display_number with nil user
  puts "Next number (nil): #{Log.next_display_number(nil)}"

  # 2. Test instantiation with rich data
  p = {
    client: "Test Client",
    tasks: [
      { "title" => "Labor", "items" => [ { "desc" => "Something", "price" => 100 } ] }
    ].to_json,
    billing_mode: "hourly",
    date: "2024-01-01"
  }

  # Mimic controller logic
  formatted_p = p.dup
  formatted_p[:tasks] = JSON.parse(p[:tasks]) rescue p[:tasks]

  log = Log.new(formatted_p)
  puts "Log created. display_number: #{log.display_number}"

  # 3. Test invoice generator
  require_relative 'app/services/invoice_generator'
  profile = Profile.new(business_name: "Test Biz", hourly_rate: 100)

  g = InvoiceGenerator.new(log, profile)
  g.render
  puts "Rendered successfully."

  # 4. Test with invalid/empty tasks
  log2 = Log.new(client: "Lazy client")
  g2 = InvoiceGenerator.new(log2, profile)
  g2.render
  puts "Rendered empty log successfully."

rescue => e
  puts "FATAL ERROR: #{e.message}"
  puts e.backtrace
end
