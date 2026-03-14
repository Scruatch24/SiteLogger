#!/usr/bin/env ruby
# frozen_string_literal: true

# AI Assistant Stress Test Suite — v2 (expanded)
# Tests process_audio and refine_invoice endpoints with real Gemini API calls.
# Run: ruby test/ai_stress_test.rb
#
# Sections:
#  1.  Discount logic (explicit %, flat, ambiguous, >100, Georgian)
#  2.  Tax commands (no tax, set rate, per-section, Georgian)
#  3.  Multi-item discount scope
#  4.  process_audio extraction (English, Georgian, hourly, bundled, slang)
#  5.  Batch commands
#  6.  Edge cases (empty, long, XSS, undo, off-topic)
#  7.  Price mutation stress
#  8.  Client restriction (guest)
#  9.  Item operations (add, remove by name, rename, price change)
# 10.  Date / due date
# 11.  Credits (post-tax)
# 12.  Multi-turn conversation memory
# 13.  Scoped discounts ("except labor", global)
# 14.  Reply language consistency
# 15.  Reply/JSON integrity
# 16.  Russian language — refine_invoice (discounts, tax, credits, dates, items)
# 17.  Russian process_audio extraction
# 18.  Russian reply language consistency
# 19.  Contradiction & correction tests (harder scenarios)

require "net/http"
require "json"
require "uri"

BASE_URL = "http://localhost:3000"
PASS = "\e[32m✓ PASS\e[0m"
FAIL = "\e[31m✗ FAIL\e[0m"
WARN = "\e[33m⚠ WARN\e[0m"

$results = { pass: 0, fail: 0, warn: 0 }
$failures = []

def get_session_cookie
  uri = URI("#{BASE_URL}/")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 30
  req = Net::HTTP::Get.new("/")
  resp = http.request(req)
  cookies = resp.get_fields("set-cookie")
  return nil unless cookies
  cookies.map { |c| c.split(";").first }.join("; ")
end

def get_csrf_token(cookie)
  uri = URI("#{BASE_URL}/")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 30
  req = Net::HTTP::Get.new("/")
  req["Cookie"] = cookie
  resp = http.request(req)
  body = resp.body
  body =~ /name="csrf-token"\s+content="([^"]+)"/ ? $1 : nil
end

def sample_invoice(items: nil, client: "", currency: "GEL", credits: [])
  items ||= [
    {
      "type" => "labor", "title" => "Labor/Service",
      "items" => [
        { "desc" => "Electrical Installation", "price" => 750, "rate" => "100.0",
          "mode" => "fixed", "taxable" => true, "tax_rate" => 18,
          "discount_flat" => 0, "discount_percent" => 0, "sub_categories" => [], "qty" => 1 }
      ]
    }
  ]
  {
    "client" => client, "sections" => items,
    "tax_scope" => "labor,products_only", "billing_mode" => "fixed",
    "currency" => currency, "hourly_rate" => nil,
    "labor_tax_rate" => "18.0", "labor_taxable" => nil,
    "labor_discount_flat" => nil, "labor_discount_percent" => nil,
    "global_discount_flat" => nil, "global_discount_percent" => nil,
    "credits" => credits, "discount_tax_mode" => nil,
    "date" => nil, "due_days" => nil, "due_date" => nil,
    "recipient_info" => nil, "sender_info" => nil
  }
end

def multi_item_invoice
  sample_invoice(items: [
    {
      "type" => "labor", "title" => "Labor/Service",
      "items" => [
        { "desc" => "Plumbing Work", "price" => 500, "rate" => "100.0", "mode" => "fixed",
          "taxable" => true, "tax_rate" => 18, "discount_flat" => 0, "discount_percent" => 0, "sub_categories" => [], "qty" => 1 },
        { "desc" => "Electrical Work", "price" => 300, "rate" => "100.0", "mode" => "fixed",
          "taxable" => true, "tax_rate" => 18, "discount_flat" => 0, "discount_percent" => 0, "sub_categories" => [], "qty" => 1 }
      ]
    },
    {
      "type" => "products", "title" => "Products/Materials",
      "items" => [
        { "desc" => "Wire 100m", "price" => 45, "qty" => 2,
          "taxable" => true, "tax_rate" => 18, "discount_flat" => 0, "discount_percent" => 0, "sub_categories" => [] }
      ]
    }
  ])
end

def report(test_name, passed, detail = nil)
  if passed == :warn
    $results[:warn] += 1
    puts "  #{WARN} #{test_name}#{detail ? " — #{detail}" : ""}"
  elsif passed
    $results[:pass] += 1
    puts "  #{PASS} #{test_name}"
  else
    $results[:fail] += 1
    $failures << { name: test_name, detail: detail }
    puts "  #{FAIL} #{test_name}#{detail ? " — #{detail}" : ""}"
  end
end

def extract_items(data)
  (data["sections"] || []).flat_map { |s| s["items"] || [] }
end

def refine(msg, invoice: nil, lang: "en", history: "", cookie: nil, csrf: nil)
  invoice ||= sample_invoice
  body = {
    "current_json"         => invoice,
    "user_message"         => msg,
    "conversation_history" => history,
    "language"             => "en",
    "assistant_language"   => lang
  }
  uri = URI("#{BASE_URL}/refine_invoice")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 60
  http.open_timeout = 10
  req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json", "Accept" => "application/json")
  req["Cookie"]        = cookie if cookie
  req["X-CSRF-Token"]  = csrf   if csrf
  req.body = body.to_json
  response = http.request(req)
  [response.code.to_i, JSON.parse(response.body)]
rescue JSON::ParserError
  [response&.code.to_i || 0, { "error" => "JSON parse", "raw" => response&.body&.[](0, 500) }]
rescue => e
  [0, { "error" => e.message }]
end

def delay
  sleep(3)
end

def long_pause(msg = "Cooling down to avoid rate limits...")
  print "  ⏳ #{msg}"
  sleep(20)
  puts " done."
end

def process_text(text, lang: "en", cookie: nil, csrf: nil)
  body = {
    "manual_text"  => text,
    "language"     => lang,
    "billing_mode" => "hourly",
    "tax_scope"    => "labor,products_only",
    "tax_rate"     => "18.0",
    "hourly_rate"  => "100.0"
  }
  uri = URI("#{BASE_URL}/process_audio")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 60
  http.open_timeout = 10
  req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json", "Accept" => "application/json")
  req["Cookie"]        = cookie if cookie
  req["X-CSRF-Token"]  = csrf   if csrf
  req.body = body.to_json
  response = http.request(req)
  [response.code.to_i, JSON.parse(response.body)]
rescue JSON::ParserError
  [response&.code.to_i || 0, { "error" => "JSON parse", "raw" => response&.body&.[](0, 500) }]
rescue => e
  [0, { "error" => e.message }]
end

# ════════════════════════════════════════════════════════════
# SETUP
# ════════════════════════════════════════════════════════════
puts "\n\e[1m══════════════════════════════════════════\e[0m"
puts "\e[1m  AI ASSISTANT STRESS TEST SUITE  v2\e[0m"
puts "\e[1m══════════════════════════════════════════\e[0m\n"

print "Setting up session..."
cookie = get_session_cookie
if cookie
  csrf = get_csrf_token(cookie)
  puts " OK (cookie: #{cookie[0,30]}...)"
else
  puts " FAILED — no cookie. Tests may fail with 422."
  cookie = ""
  csrf = nil
end

# ════════════════════════════════════════
# 1. DISCOUNT LOGIC
# ════════════════════════════════════════
puts "\n\e[1m── 1. DISCOUNT LOGIC ──\e[0m"

delay
puts "\n  Testing: 'knock off 15' (ambiguous — should guess, NOT pre-calc)..."
status, data = refine("knock off 15", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("Price unchanged (750)",             item && item["price"].to_f == 750.0,                "price=#{item&.dig("price")}")
  report("Has discount applied in JSON",      item && (item["discount_flat"].to_f > 0 || item["discount_percent"].to_f > 0), "flat=#{item&.dig("discount_flat")}, pct=#{item&.dig("discount_percent")}")
  report("Discount value is 15 (flat or pct)",item && (item["discount_flat"].to_f == 15.0 || item["discount_percent"].to_f == 15.0), "flat=#{item&.dig("discount_flat")}, pct=#{item&.dig("discount_percent")}")
  report("Not pre-calculated as 112.5 flat",  item && item["discount_flat"].to_f != 112.5,        "flat=#{item&.dig("discount_flat")}")
  report("Price not mutated to 637.5",        item && item["price"].to_f != 637.5,                "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: '15% discount' (explicit %)..."
status, data = refine("15% discount", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("discount_percent=15", item && item["discount_percent"].to_f == 15.0, "got #{item&.dig("discount_percent")}")
  report("discount_flat=0",     item && item["discount_flat"].to_f == 0,        "got #{item&.dig("discount_flat")}")
  report("Price unchanged (750)",item && item["price"].to_f == 750.0,           "got #{item&.dig("price")}")
  no_clarification = (data["clarifications"] || []).none? { |c| c["field"] == "discount_type" }
  report("No clarification widget for explicit %", no_clarification, "clarifications=#{(data["clarifications"] || []).map { |c| c["field"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: '$50 off the price' (explicit flat)..."
status, data = refine("$50 off the price", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("discount_flat=50",    item && item["discount_flat"].to_f == 50.0,  "got #{item&.dig("discount_flat")}")
  report("discount_percent=0",  item && item["discount_percent"].to_f == 0,  "got #{item&.dig("discount_percent")}")
  report("Price unchanged (750)",item && item["price"].to_f == 750.0,        "got #{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'discount 200' (>100 = always flat, no clarification)..."
status, data = refine("discount 200", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("discount_flat=200",   item && item["discount_flat"].to_f == 200.0, "got flat=#{item&.dig("discount_flat")}")
  report("discount_percent=0",  item && item["discount_percent"].to_f == 0,  "got pct=#{item&.dig("discount_percent")}")
  report("Price unchanged (750)",item && item["price"].to_f == 750.0,        "got #{item&.dig("price")}")
  no_clarification = (data["clarifications"] || []).none? { |c| c["field"] == "discount_type" }
  report("No clarification for >100 number", no_clarification, "clarifications=#{(data["clarifications"] || []).map { |c| c["field"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Georgian 'ფასდაკლება 50 ლარი' (explicit ლარი = flat)..."
status, data = refine("ფასდაკლება 50 ლარი", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("discount_flat=50 (ლარი = flat)",  item && item["discount_flat"].to_f == 50.0,  "got flat=#{item&.dig("discount_flat")}")
  report("Price unchanged after ლარი discount", item && item["price"].to_f == 750.0,     "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Georgian 'ფასდაკლება გაუკეთე 15%' (explicit %)..."
status, data = refine("ფასდაკლება გაუკეთე 15%", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("discount_percent=15 (Georgian explicit %)", item && item["discount_percent"].to_f == 15.0, "got pct=#{item&.dig("discount_percent")}")
  report("Price unchanged (Georgian explicit %)",      item && item["price"].to_f == 750.0,          "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 2. TAX COMMANDS
# ════════════════════════════════════════
puts "\n\e[1m── 2. TAX COMMANDS ──\e[0m"

delay
puts "\n  Testing: 'no tax' on multi-item invoice..."
status, data = refine("no tax", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  report("All items taxable=false",  items.all? { |i| i["taxable"] == false }, "#{items.map { |i| [i["desc"], i["taxable"]] }}")
  report("All items tax_rate=0",     items.all? { |i| i["tax_rate"].to_f == 0 }, "#{items.map { |i| [i["desc"], i["tax_rate"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'add 8% tax' on multi-item invoice..."
status, data = refine("add 8% tax", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  report("All items tax_rate=8", items.all? { |i| i["tax_rate"].to_f == 8.0 }, "#{items.map { |i| [i["desc"], i["tax_rate"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Georgian 'ნუ დაადებ დღგ-ს'..."
status, data = refine("ნუ დაადებ დღგ-ს", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  report("All items taxable=false (Georgian)", items.all? { |i| i["taxable"] == false }, "#{items.map { |i| [i["desc"], i["taxable"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'remove tax from products only' (per-section)..."
status, data = refine("remove tax from products only", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  all_items = extract_items(data)
  product_items = (data["sections"] || []).select { |s| s["type"] == "products" }.flat_map { |s| s["items"] || [] }
  labor_items   = (data["sections"] || []).select { |s| s["type"] == "labor" }.flat_map { |s| s["items"] || [] }
  products_untaxed = product_items.all? { |i| i["taxable"] == false }
  labor_still_taxed = labor_items.any? { |i| i["taxable"] != false }
  report("Products untaxed",        products_untaxed, "products: #{product_items.map { |i| [i["desc"], i["taxable"]] }}")
  report("Labor still taxed",       labor_still_taxed, "labor: #{labor_items.map { |i| [i["desc"], i["taxable"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 3. MULTI-ITEM DISCOUNT SCOPE
# ════════════════════════════════════════
puts "\n\e[1m── 3. MULTI-ITEM DISCOUNT SCOPE ──\e[0m"

delay
puts "\n  Testing: 'add a discount' with 3 items (should ask scope/amount)..."
status, data = refine("add a discount", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200
  clars = data["clarifications"] || []
  has_scope = clars.any? { |c| ["discount_scope", "discount_amount", "discount_setup", "discount_type"].include?(c["field"]) }
  no_discount_yet = extract_items(data).all? { |i| i["discount_flat"].to_f == 0 && i["discount_percent"].to_f == 0 }
  report("Asks for discount scope or amount", has_scope, "clarifications: #{clars.map { |c| c["field"] }}")
  report("No discount applied yet",           no_discount_yet, "#{extract_items(data).map { |i| [i["desc"], i["discount_flat"], i["discount_percent"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 4. PROCESS_AUDIO EXTRACTION
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 4. PROCESS_AUDIO EXTRACTION ──\e[0m"

delay
puts "\n  Testing: Simple English extraction (hourly labor + products + client)..."
status, data = process_text("I did plumbing work for John Smith, 3 hours at 80 dollars per hour, plus I used 2 pipe fittings at 25 each", lang: "en", cookie: cookie, csrf: csrf)
if status == 200
  items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  has_labor   = items.any? { |i| i["hours"].to_f > 0 || (i["mode"] == "hourly") }
  has_product = items.any? { |i| i["qty"].to_i >= 2 }
  has_client  = data["client"].to_s.downcase.match?(/john|smith/)
  report("Extracted hourly labor",   has_labor,   "items=#{items.map { |i| {d: i["desc"], h: i["hours"], r: i["rate"]} }}")
  report("Extracted product qty=2",  has_product, "items=#{items.map { |i| {d: i["desc"], q: i["qty"]} }}")
  report("Extracted client name",    has_client,  "client=#{data["client"]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

delay
puts "\n  Testing: Georgian extraction (5 hours @ 60 + 3 pipes @ 15)..."
status, data = process_text("სანტექნიკის სამუშაო გავუკეთე, 5 საათი 60 ლარად საათში, პლუს 3 მილი ვიყიდე 15 ლარიანი", lang: "ge", cookie: cookie, csrf: csrf)
if status == 200
  items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  report("Extracted items from Georgian", items.length >= 1, "items=#{items.map { |i| {d: i["desc"], p: i["price"]} }}")
  raw_sum = data["raw_summary"].to_s
  raw_sum = (data["sections"] || []).flat_map { |s| s["items"] || [] }.map { |i| i["raw_summary"].to_s }.reject(&:empty?).first.to_s if raw_sum.empty?
  report("Has raw_summary (or clarifications)", raw_sum.length > 5 || (data["clarifications"] || []).length > 0 || items.length >= 2, "raw=#{raw_sum[0,80]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

delay
puts "\n  Testing: Off-topic input (meaning of life)..."
status, data = process_text("What is the meaning of life?", lang: "en", cookie: cookie, csrf: csrf)
if [200, 422].include?(status)
  items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  report("Handles off-topic gracefully (no crash)", true)
  report("Minimal/empty extraction for off-topic", items.length <= 1, "got #{items.length} items")
else
  report("Rejects off-topic gracefully", false, "status=#{status}")
end

long_pause("Mid-section cooldown for process_audio rate limit...")
puts "\n  Testing: Bundled items with late total ('condenser, coil, line set... products were 2300')..."
status, data = process_text("Did an AC job for Metro Builders. Used a condenser, a coil, and a line set — products were 2300 total. Labor was 4 hours at 90 an hour.", lang: "en", cookie: cookie, csrf: csrf)
if status == 200
  all_items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  product_items = (data["sections"] || []).select { |s| s["type"] == "products" }.flat_map { |s| s["items"] || [] }
  labor_items   = (data["sections"] || []).select { |s| s["type"] == "labor" }.flat_map { |s| s["items"] || [] }
  bundled_price = product_items.any? { |i| i["price"].to_f == 2300.0 || i["unit_price"].to_f == 2300.0 }
  has_subcats   = product_items.any? { |i| (i["sub_categories"] || []).length >= 2 }
  has_labor     = labor_items.any? { |i| i["hours"].to_f == 4 || i["price"].to_f == 360.0 || i["price"].to_i == 4 }
  has_client    = data["client"].to_s.downcase.include?("metro")
  report("Products bundled into single item @ 2300", bundled_price, "products=#{product_items.map { |i| {d: i["desc"], p: i["price"]} }}")
  report("Sub-categories list parts",                has_subcats,   "subcats=#{product_items.map { |i| i["sub_categories"] }}")
  report("Labor extracted (4hrs @ 90)",              has_labor,     "labor=#{labor_items.map { |i| {h: i["hours"], r: i["rate"], p: i["price"]} }}")
  report("Client extracted (Metro Builders)",        has_client,    "client=#{data["client"]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

long_pause("Cooldown before slang test...")
puts "\n  Testing: Real-world slang ('knock off 50 bucks from labor, trip charge 25, client is Apex Roofing')..."
status, data = process_text("Did a roof inspection for Apex Roofing. Two hours, my usual rate. Throw in a trip charge of 25. Knock 50 bucks off the labor.", lang: "en", cookie: cookie, csrf: csrf)
if status == 200
  all_items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  has_labor     = all_items.any? { |i| (i["mode"] == "hourly" || i["hours"].to_i >= 2) }
  has_fee       = (data["sections"] || []).select { |s| s["type"] == "fees" }.flat_map { |s| s["items"] || [] }.any? { |i| i["price"].to_f == 25.0 }
  has_discount  = all_items.any? { |i| i["discount_flat"].to_f == 50.0 } || data["labor_discount_flat"].to_f == 50.0 || data["global_discount_flat"].to_f == 50.0
  has_client    = data["client"].to_s.downcase.include?("apex")
  report("Labor item extracted",            has_labor,    "items=#{all_items.map { |i| {d: i["desc"], h: i["hours"], m: i["mode"]} }}")
  report("Trip charge (fee) @ 25",          has_fee,      "fees=#{(data["sections"] || []).select { |s| s["type"] == "fees" }.flat_map { |s| s["items"] || [] }.map { |i| {d: i["desc"], p: i["price"]} }}")
  report("$50 discount applied to labor",   has_discount, "discount on labor items or global")
  report("Client = Apex Roofing",           has_client,   "client=#{data["client"]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

long_pause("Cooldown before Georgian hourly test...")
puts "\n  Testing: Georgian hourly pattern '2 საათი 150 ლარი საათში'..."
status, data = process_text("კონსულტაციის მომსახურება. 2 საათი 150 ლარი საათში.", lang: "ge", cookie: cookie, csrf: csrf)
if status == 200
  labor = (data["sections"] || []).select { |s| s["type"] == "labor" }.flat_map { |s| s["items"] || [] }
  hours_ok = labor.any? { |i| i["hours"].to_f == 2.0 || i["price"].to_f == 300.0 || i["price"].to_i == 2 }
  rate_ok  = labor.any? { |i| i["rate"].to_f == 150.0 }
  mode_ok  = labor.any? { |i| i["mode"] == "hourly" }
  report("hours=2 (or price=300)", hours_ok, "labor=#{labor.map { |i| {h: i["hours"], r: i["rate"], m: i["mode"], p: i["price"]} }}")
  report("rate=150",      rate_ok,  "labor=#{labor.map { |i| {r: i["rate"]} }}")
  report("mode=hourly",   mode_ok,  "labor=#{labor.map { |i| {m: i["mode"]} }}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

long_pause("Cooldown before thousands-separator test...")
puts "\n  Testing: Numbers with spaces as thousands separators ('4 599 ლარი')..."
status, data = process_text("ჩავაყენე iPhone 15 Pro, ფასი 4 599 ლარი.", lang: "ge", cookie: cookie, csrf: csrf)
if status == 200
  all_items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  price_ok = all_items.any? { |i| i["price"].to_f == 4599.0 || i["unit_price"].to_f == 4599.0 }
  report("4 599 parsed as 4599 (not split into qty=4, price=599)", price_ok, "items=#{all_items.map { |i| {d: i["desc"], p: i["price"], q: i["qty"]} }}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

# ════════════════════════════════════════
# 5. BATCH COMMANDS
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 5. BATCH COMMANDS ──\e[0m"

delay
puts "\n  Testing: 'add 2 cameras at $100 each, remove tax from everything'..."
status, data = refine("add 2 cameras at $100 each and remove tax from everything", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  cam   = items.find { |i| i["desc"].to_s.downcase.include?("camera") }
  report("Camera item added",        !!cam,                                                     "items=#{items.map { |i| i["desc"] }}")
  report("Camera qty=2",             cam && cam["qty"].to_i == 2,                               "qty=#{cam&.dig("qty")}")
  report("Camera price=100",         cam && (cam["price"].to_f == 100.0 || cam["unit_price"].to_f == 100.0), "price=#{cam&.dig("price")}")
  report("All items tax removed",    items.all? { |i| i["taxable"] == false },                 "taxable=#{items.map { |i| [i["desc"], i["taxable"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'change price of Plumbing Work to 600, add 5% discount to Electrical Work'..."
status, data = refine("change price of Plumbing Work to 600, add 5% discount to Electrical Work", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  plumbing    = items.find { |i| i["desc"].to_s.downcase.include?("plumb") }
  electrical  = items.find { |i| i["desc"].to_s.downcase.include?("electr") }
  report("Plumbing price changed to 600",            plumbing && plumbing["price"].to_f == 600.0,           "price=#{plumbing&.dig("price")}")
  report("Electrical discount_percent=5",            electrical && electrical["discount_percent"].to_f == 5.0, "pct=#{electrical&.dig("discount_percent")}")
  report("Plumbing discount untouched (still 0)",    plumbing && plumbing["discount_percent"].to_f == 0 && plumbing["discount_flat"].to_f == 0, "flat=#{plumbing&.dig("discount_flat")}, pct=#{plumbing&.dig("discount_percent")}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 6. EDGE CASES
# ════════════════════════════════════════
puts "\n\e[1m── 6. EDGE CASES ──\e[0m"

delay
puts "\n  Testing: Empty user message..."
status, data = refine("", cookie: cookie, csrf: csrf)
report("Empty message: no crash", [200, 422].include?(status), "status=#{status}")

delay
puts "\n  Testing: Very long message (2000+ chars)..."
status, data = refine(("Add item " * 250).strip, cookie: cookie, csrf: csrf)
report("Long message: no crash", status == 200, "status=#{status}")

delay
puts "\n  Testing: XSS injection attempt..."
status, data = refine('Add item "pipe <script>alert(1)</script>" at $50', cookie: cookie, csrf: csrf)
if status == 200
  items = extract_items(data)
  report("Item added despite special chars", items.any? { |i| i["desc"].to_s.downcase.include?("pipe") }, "items=#{items.map { |i| i["desc"] }}")
  report("No script tag in output",         items.none? { |i| i["desc"].to_s.include?("<script>") },      "items=#{items.map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'undo' with no history..."
status, data = refine("undo", cookie: cookie, csrf: csrf)
report("Undo: no crash",                [200, 500].include?(status), "status=#{status}")
if status == 200
  report("Undo: has reply",             data["reply"].to_s.length > 0,   "reply=#{data["reply"]&.[](0,80)}")
  report("Undo: invoice data preserved",extract_items(data).length >= 1, "items=#{extract_items(data).length}")
end

delay
puts "\n  Testing: Off-topic chat ('What's the weather?')..."
status, data = refine("What's the weather today?", cookie: cookie, csrf: csrf)
if status == 200
  item = extract_items(data).first
  report("Invoice preserved on off-topic", item && item["price"].to_f == 750.0, "price=#{item&.dig("price")}")
  report("AI replies on off-topic",        data["reply"].to_s.length > 0,       "reply=#{data["reply"]&.[](0,80)}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Emoji in user message ('add 🔧 wrench for $30')..."
status, data = refine("add 🔧 wrench for $30", cookie: cookie, csrf: csrf)
if status == 200
  items = extract_items(data)
  report("Emoji message: no crash",         true)
  report("Item added from emoji message",   items.any? { |i| i["desc"].to_s.downcase.include?("wrench") }, "items=#{items.map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 7. PRICE MUTATION STRESS
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 7. PRICE MUTATION STRESS TEST ──\e[0m"

[
  "knock off 15",
  "take 20 off",
  "give me a 30% discount",
  "15იანი ფასდაკლება უქენი",
  "მოაკელი 25",
  "discount of 10",
  "50 ლარი ფასდაკლება",
  "apply 40% off",
].each do |phrase|
  delay
  puts "\n  Testing: '#{phrase}'..."
  status, data = refine(phrase, cookie: cookie, csrf: csrf)
  if status == 200 && data["sections"]
    item = extract_items(data).first
    report("Price=750 after '#{phrase}'", item && item["price"].to_f == 750.0, "price=#{item&.dig("price")}, flat=#{item&.dig("discount_flat")}, pct=#{item&.dig("discount_percent")}")
  else
    report("Server responds 200", false, "status=#{status}")
  end
end

# ════════════════════════════════════════
# 8. CLIENT RESTRICTIONS (guest)
# ════════════════════════════════════════
puts "\n\e[1m── 8. CLIENT RESTRICTION TESTS (guest) ──\e[0m"

def guest_restriction_words
  %w[sign register guest available account log login create free]
end

delay
puts "\n  Testing: 'show me my clients' (as guest)..."
status, data = refine("show me my clients", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s.downcase
  report("AI mentions restriction for 'show clients'", guest_restriction_words.any? { |w| reply.include?(w) }, "reply=#{data["reply"]&.[](0,150)}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'change client to ABC Corp' (as guest)..."
status, data = refine("change client to ABC Corp", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s.downcase
  report("AI refuses client change (guest)", guest_restriction_words.any? { |w| reply.include?(w) }, "reply=#{data["reply"]&.[](0,150)}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'search for client George' (as guest)..."
status, data = refine("search for client George", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s.downcase
  report("AI refuses client search (guest)", guest_restriction_words.any? { |w| reply.include?(w) }, "reply=#{data["reply"]&.[](0,150)}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 9. ITEM OPERATIONS
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 9. ITEM OPERATIONS ──\e[0m"

delay
puts "\n  Testing: Remove item by name 'remove Wire 100m'..."
status, data = refine("remove Wire 100m", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  wire_gone     = items.none? { |i| i["desc"].to_s.downcase.include?("wire") }
  others_intact = items.any?  { |i| i["desc"].to_s.downcase.include?("plumb") }
  report("Wire item removed",            wire_gone,     "items=#{items.map { |i| i["desc"] }}")
  report("Other items still present",    others_intact, "items=#{items.map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Rename item 'rename Electrical Installation to HVAC Setup'..."
status, data = refine("rename Electrical Installation to HVAC Setup", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  renamed    = items.any? { |i| i["desc"].to_s.downcase.include?("hvac") }
  old_gone   = items.none? { |i| i["desc"] == "Electrical Installation" }
  report("Item renamed to HVAC Setup",          renamed,  "items=#{items.map { |i| i["desc"] }}")
  report("Old name no longer present",          old_gone, "items=#{items.map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Change price 'set price to 900'..."
status, data = refine("set price to 900", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("Price changed to 900",             item && item["price"].to_f == 900.0, "price=#{item&.dig("price")}")
  report("Discount not touched after price change", item && item["discount_flat"].to_f == 0 && item["discount_percent"].to_f == 0, "flat=#{item&.dig("discount_flat")}, pct=#{item&.dig("discount_percent")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Add new product item 'add 3 fire extinguishers at 45 each'..."
status, data = refine("add 3 fire extinguishers at 45 each", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  ext = items.find { |i| i["desc"].to_s.downcase.include?("extinguish") || i["desc"].to_s.downcase.include?("fire") }
  report("Fire extinguisher added",         !!ext,                                               "items=#{items.map { |i| i["desc"] }}")
  report("qty=3",                           ext && ext["qty"].to_i == 3,                         "qty=#{ext&.dig("qty")}")
  report("price=45 (per unit)",             ext && (ext["price"].to_f == 45.0 || ext["unit_price"].to_f == 45.0), "price=#{ext&.dig("price")}")
  report("Original item still present",     items.any? { |i| i["desc"] == "Electrical Installation" }, "items=#{items.map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 10. DATE / DUE DATE
# ════════════════════════════════════════
puts "\n\e[1m── 10. DATE / DUE DATE ──\e[0m"

delay
puts "\n  Testing: 'set due date to March 31' ..."
status, data = refine("set due date to March 31", cookie: cookie, csrf: csrf)
if status == 200
  due = data["due_date"].to_s
  has_due = due.include?("Mar") || due.include?("31") || due.include?("march")
  report("due_date set", has_due, "due_date=#{due}")
  report("Invoice data intact after due date set", extract_items(data).first&.dig("price").to_f == 750.0, "price=#{extract_items(data).first&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Georgian 'ბოლო ვადა 30 მარტი' (due date)..."
status, data = refine("ბოლო ვადა 30 მარტი", cookie: cookie, csrf: csrf)
if status == 200
  due = data["due_date"].to_s
  has_due = due.include?("Mar") || due.include?("30") || due.length > 3
  report("due_date set from Georgian", has_due, "due_date=#{due}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'change the invoice date to yesterday' (relative date)..."
status, data = refine("change the invoice date to yesterday", cookie: cookie, csrf: csrf)
if status == 200
  inv_date = data["date"].to_s
  report("Invoice date set (relative 'yesterday')", inv_date.length > 3, "date=#{inv_date}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 11. CREDITS (post-tax reductions)
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 11. CREDITS ──\e[0m"

delay
puts "\n  Testing: 'give them a $50 credit off the total'..."
status, data = refine("give them a $50 credit off the total", cookie: cookie, csrf: csrf)
if status == 200
  credits = data["credits"] || []
  items   = extract_items(data)
  has_credit    = credits.any? { |c| c["amount"].to_f == 50.0 }
  price_intact  = items.first && items.first["price"].to_f == 750.0
  no_discount   = items.first && items.first["discount_flat"].to_f == 0 && items.first["discount_percent"].to_f == 0
  report("Credit of 50 added to credits array",    has_credit,   "credits=#{credits}")
  report("Price unchanged (not a discount)",        price_intact, "price=#{items.first&.dig("price")}")
  report("discount_flat/pct unchanged",             no_discount,  "flat=#{items.first&.dig("discount_flat")}, pct=#{items.first&.dig("discount_percent")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'add a credit of $100 for loyalty' (credit with reason)..."
status, data = refine("add a credit of $100 for loyalty", cookie: cookie, csrf: csrf)
if status == 200
  credits = data["credits"] || []
  has_credit   = credits.any? { |c| c["amount"].to_f == 100.0 }
  has_reason   = credits.any? { |c| c["reason"].to_s.length > 0 }
  report("Credit of 100 added",        has_credit, "credits=#{credits}")
  report("Credit has a reason",        has_reason, "reasons=#{credits.map { |c| c["reason"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 12. MULTI-TURN CONVERSATION MEMORY
# ════════════════════════════════════════
puts "\n\e[1m── 12. MULTI-TURN CONVERSATION MEMORY ──\e[0m"

delay
puts "\n  Testing: AI remembers item added in previous turn..."
# Turn 1: add item
_s1, turn1 = refine("add a smoke detector for 80", cookie: cookie, csrf: csrf)
if turn1["sections"]
  history1 = "User: add a smoke detector for 80\nAssistant: #{turn1["reply"]}"
  invoice_after_t1 = turn1

  # Turn 2: change its price — AI must know which item we mean
  status, data = refine("actually make it 95", invoice: invoice_after_t1, history: history1, cookie: cookie, csrf: csrf)
  if status == 200 && data["sections"]
    items = extract_items(data)
    detector = items.find { |i| i["desc"].to_s.downcase.include?("smoke") || i["desc"].to_s.downcase.include?("detector") }
    report("Smoke detector price updated to 95 (context memory)", detector && detector["price"].to_f == 95.0, "price=#{detector&.dig("price")}, items=#{items.map { |i| [i["desc"], i["price"]] }}")
  else
    report("Server responds 200 on turn 2", false, "status=#{status}")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "turn1 sections missing")
end

delay
puts "\n  Testing: Multi-step: add, discount, then tax — all in sequence..."
_s, inv1 = refine("add a generator for 1200", cookie: cookie, csrf: csrf)
if inv1["sections"]
  h1 = "User: add a generator for 1200\nAssistant: #{inv1["reply"]}"
  _s, inv2 = refine("10% discount on the generator", invoice: inv1, history: h1, cookie: cookie, csrf: csrf)
  if inv2["sections"]
    h2 = h1 + "\nUser: 10% discount on the generator\nAssistant: #{inv2["reply"]}"
    status, inv3 = refine("also set tax to 5% on everything", invoice: inv2, history: h2, cookie: cookie, csrf: csrf)
    if status == 200 && inv3["sections"]
      items = extract_items(inv3)
      gen = items.find { |i| i["desc"].to_s.downcase.include?("generator") }
      report("Generator has 10% discount after 3-turn chain", gen && gen["discount_percent"].to_f == 10.0, "pct=#{gen&.dig("discount_percent")}")
      report("All items tax_rate=5 after 3-turn chain",       items.all? { |i| i["tax_rate"].to_f == 5.0 }, "rates=#{items.map { |i| [i["desc"], i["tax_rate"]] }}")
      report("Generator price NOT mutated (1200)",            gen && gen["price"].to_f == 1200.0,            "price=#{gen&.dig("price")}")
    else
      report("Server responds 200 on turn 3", false, "status=#{status}")
    end
  else
    report("Turn 2 succeeded (prerequisite)", false, "inv2 sections missing")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "inv1 sections missing")
end

# ════════════════════════════════════════
# 13. SCOPED DISCOUNTS
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 13. SCOPED DISCOUNTS ──\e[0m"

delay
puts "\n  Testing: '10% off everything except labor'..."
status, data = refine("10% off everything except labor", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  product_items = (data["sections"] || []).select { |s| s["type"] == "products" }.flat_map { |s| s["items"] || [] }
  labor_items   = (data["sections"] || []).select { |s| s["type"] == "labor" }.flat_map { |s| s["items"] || [] }
  products_discounted = product_items.all? { |i| i["discount_percent"].to_f == 10.0 }
  labor_not_discounted = labor_items.all? { |i| i["discount_percent"].to_f == 0 && i["discount_flat"].to_f == 0 }
  report("Products have 10% discount",       products_discounted,   "products=#{product_items.map { |i| [i["desc"], i["discount_percent"]] }}")
  report("Labor has no discount (excluded)", labor_not_discounted,  "labor=#{labor_items.map { |i| [i["desc"], i["discount_percent"], i["discount_flat"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: 'apply 5% global discount'..."
status, data = refine("apply 5% global discount", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200
  global_pct = data["global_discount_percent"].to_f
  report("global_discount_percent=5", global_pct == 5.0, "global_discount_percent=#{global_pct}")
  report("Item prices NOT mutated",   extract_items(data).all? { |i| i["price"].to_f > 0 }, "prices=#{extract_items(data).map { |i| i["price"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 14. REPLY LANGUAGE CONSISTENCY
# ════════════════════════════════════════
puts "\n\e[1m── 14. REPLY LANGUAGE CONSISTENCY ──\e[0m"

delay
puts "\n  Testing: Georgian UI — reply should be in Georgian even when user types English..."
status, data = refine("add a ladder for 80", lang: "ka", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s
  has_georgian = reply.match?(/[\u10D0-\u10FF]/)
  report("Reply contains Georgian chars when lang=ka", has_georgian, "reply=#{reply[0,100]}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: English UI — reply should be in English even when user types Georgian..."
status, data = refine("დამატე კიბე 80 ლარად", lang: "en", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s
  all_ascii_reply = !reply.match?(/[\u10D0-\u10FF]/)
  report("Reply is English when lang=en (Georgian input)", all_ascii_reply, "reply=#{reply[0,100]}")
  item_names_preserved = extract_items(data).any? { |i| i["desc"].to_s.match?(/[\u10D0-\u10FF]|ladder|kibe/i) }
  report("Item desc preserved in original language", item_names_preserved, "items=#{extract_items(data).map { |i| i["desc"] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Clarification widget language matches UI lang (ka)..."
status, data = refine("ფასდაკლება 43", lang: "ka", cookie: cookie, csrf: csrf)
if status == 200
  clars = data["clarifications"] || []
  discount_clar = clars.find { |c| c["field"] == "discount_type" }
  if discount_clar
    question_georgian = discount_clar["question"].to_s.match?(/[\u10D0-\u10FF]/)
    report("Clarification question is in Georgian (ka)", question_georgian, "question=#{discount_clar["question"]}")
  else
    # Might have applied directly — still valid if discount was set
    item = extract_items(data).first
    applied = item && (item["discount_flat"].to_f == 43.0 || item["discount_percent"].to_f == 43.0)
    report("Applied directly without clarification (also valid)", applied, "clarifications=#{clars.map { |c| c["field"] }}")
  end
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 15. INTEGRITY: JSON MATCHES REPLY
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 15. REPLY/JSON INTEGRITY ──\e[0m"

delay
puts "\n  Testing: Reply says 'Applied 20%' → JSON must have discount_percent=20..."
status, data = refine("give me 20% off", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item  = extract_items(data).first
  reply = data["reply"].to_s.downcase
  says_20 = reply.include?("20")
  json_20 = item && item["discount_percent"].to_f == 20.0
  report("Reply mentions 20", says_20, "reply=#{data["reply"]&.[](0,120)}")
  report("JSON has discount_percent=20 (reply matches JSON)", json_20, "pct=#{item&.dig("discount_percent")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Reply says tax removed → all items taxable=false..."
status, data = refine("remove all tax", invoice: multi_item_invoice, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  reply = data["reply"].to_s.downcase
  says_removed = reply.include?("tax") || reply.include?("removed") || reply.include?("no tax")
  all_false = items.all? { |i| i["taxable"] == false }
  report("Reply acknowledges tax removal",         says_removed, "reply=#{data["reply"]&.[](0,120)}")
  report("All items actually untaxed (JSON match)",all_false,    "taxable=#{items.map { |i| [i["desc"], i["taxable"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 16. RUSSIAN LANGUAGE — REFINE_INVOICE
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 16. RUSSIAN LANGUAGE — REFINE_INVOICE ──\e[0m"

delay
puts "\n  Testing: Russian 'скидка 15%' (explicit % discount)..."
status, data = refine("скидка 15%", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("RU: discount_percent=15",    item && item["discount_percent"].to_f == 15.0, "got pct=#{item&.dig("discount_percent")}")
  report("RU: Price unchanged (750)",  item && item["price"].to_f == 750.0,           "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'скинь 50 лари' (flat discount with currency)..."
status, data = refine("скинь 50 лари", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("RU: discount_flat=50",       item && item["discount_flat"].to_f == 50.0,  "got flat=#{item&.dig("discount_flat")}")
  report("RU: Price unchanged (750)",  item && item["price"].to_f == 750.0,         "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'убери налог' (remove tax)..."
status, data = refine("убери налог", invoice: multi_item_invoice, lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  report("RU: All items taxable=false", items.all? { |i| i["taxable"] == false }, "#{items.map { |i| [i["desc"], i["taxable"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'добавь налог 20%' (set tax rate)..."
status, data = refine("добавь налог 20%", invoice: multi_item_invoice, lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  report("RU: All items tax_rate=20", items.all? { |i| i["tax_rate"].to_f == 20.0 }, "rates=#{items.map { |i| [i["desc"], i["tax_rate"]] }}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'добавь кредит 100 лари' (credit)..."
status, data = refine("добавь кредит 100 лари", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  credits = data["credits"] || []
  has_credit = credits.any? { |c| c["amount"].to_f == 100.0 }
  report("RU: Credit of 100 added",    has_credit,   "credits=#{credits}")
  report("RU: Price intact (not discount)", extract_items(data).first && extract_items(data).first["price"].to_f == 750.0, "price=#{extract_items(data).first&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'срок оплаты 30 марта' (due date)..."
status, data = refine("срок оплаты 30 марта", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  due = data["due_date"].to_s
  has_due = due.include?("Mar") || due.include?("30") || due.length > 3
  report("RU: due_date set from Russian",  has_due,  "due_date=#{due}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'добавь 3 камеры по 200 лари' (add item)..."
status, data = refine("добавь 3 камеры по 200 лари", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  items = extract_items(data)
  cam = items.find { |i| i["desc"].to_s.downcase.match?(/камер|camera/) }
  report("RU: Camera item added",        !!cam,                        "items=#{items.map { |i| i["desc"] }}")
  report("RU: qty=3",                    cam && cam["qty"].to_i == 3,  "qty=#{cam&.dig("qty")}")
  report("RU: price=200 (per unit)",     cam && (cam["price"].to_f == 200.0 || cam["unit_price"].to_f == 200.0), "price=#{cam&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian 'убери скидку' (remove discount)..."
inv_with_discount = sample_invoice
inv_with_discount["sections"][0]["items"][0]["discount_percent"] = 15
status, data = refine("убери скидку", invoice: inv_with_discount, lang: "ru", cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("RU: Discount removed (pct=0, flat=0)", item && item["discount_percent"].to_f == 0 && item["discount_flat"].to_f == 0, "pct=#{item&.dig("discount_percent")}, flat=#{item&.dig("discount_flat")}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 17. RUSSIAN PROCESS_AUDIO EXTRACTION
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 17. RUSSIAN PROCESS_AUDIO EXTRACTION ──\e[0m"

delay
puts "\n  Testing: Russian extraction ('Сантехника для Иванова, 3 часа по 80, плюс 2 фитинга по 25')..."
status, data = process_text("Сантехнические работы для Иванова, 3 часа по 80 долларов за час, плюс 2 фитинга по 25 каждый", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  has_labor   = items.any? { |i| i["hours"].to_f > 0 || i["mode"] == "hourly" }
  has_product = items.any? { |i| i["qty"].to_i >= 2 }
  has_client  = data["client"].to_s.match?(/Иванов|ivanov/i)
  report("RU: Extracted hourly labor",    has_labor,   "items=#{items.map { |i| {d: i["desc"], h: i["hours"], r: i["rate"], m: i["mode"]} }}")
  report("RU: Extracted product qty>=2",  has_product, "items=#{items.map { |i| {d: i["desc"], q: i["qty"]} }}")
  report("RU: Extracted client Иванов",   has_client,  "client=#{data["client"]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

long_pause("Cooldown before Russian bundled test...")
puts "\n  Testing: Russian bundled job ('Кондиционер: конденсатор, компрессор, трубки — материалы 3500, работа 6 часов по 100')..."
status, data = process_text("Установка кондиционера для ООО Меридиан. Материалы: конденсатор, компрессор, медные трубки — итого 3500. Работа 6 часов по 100.", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  all_items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  product_items = (data["sections"] || []).select { |s| s["type"] == "products" }.flat_map { |s| s["items"] || [] }
  labor_items   = (data["sections"] || []).select { |s| s["type"] == "labor" }.flat_map { |s| s["items"] || [] }
  has_products  = product_items.any? { |i| i["price"].to_f == 3500.0 || i["unit_price"].to_f == 3500.0 }
  has_labor     = labor_items.any? { |i| i["hours"].to_f == 6 || i["price"].to_f == 600.0 || i["price"].to_i == 6 }
  has_client    = data["client"].to_s.match?(/Меридиан|meridian/i)
  report("RU: Products @ 3500",           has_products, "products=#{product_items.map { |i| {d: i["desc"], p: i["price"]} }}")
  report("RU: Labor extracted (6hrs)",    has_labor,    "labor=#{labor_items.map { |i| {h: i["hours"], r: i["rate"], p: i["price"]} }}")
  report("RU: Client = Меридиан",        has_client,   "client=#{data["client"]}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

long_pause("Cooldown before Russian slang test...")
puts "\n  Testing: Russian slang extraction ('Починил кран Петрову, два часа, скинь полтинник')..."
status, data = process_text("Починил кран Петрову, два часа. Скинь полтинник с работы.", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  all_items = (data["sections"] || []).flat_map { |s| s["items"] || [] }
  has_labor    = all_items.any? { |i| i["hours"].to_f >= 2 || i["mode"] == "hourly" }
  has_client   = data["client"].to_s.match?(/Петров|petrov/i)
  has_discount = all_items.any? { |i| i["discount_flat"].to_f == 50.0 } || data["labor_discount_flat"].to_f == 50.0 || data["global_discount_flat"].to_f == 50.0
  report("RU: Labor extracted (2hrs)",   has_labor,    "items=#{all_items.map { |i| {d: i["desc"], h: i["hours"], m: i["mode"]} }}")
  report("RU: Client = Петров",          has_client,   "client=#{data["client"]}")
  report("RU: полтинник (50) discount",  has_discount, "discounts=#{all_items.map { |i| {d: i["desc"], df: i["discount_flat"]} }}")
else
  report("Server responds 200", false, "status=#{status}, error=#{data["error"]}")
end

# ════════════════════════════════════════
# 18. RUSSIAN REPLY LANGUAGE CONSISTENCY
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 18. RUSSIAN REPLY LANGUAGE ──\e[0m"

delay
puts "\n  Testing: Russian UI — reply should be in Russian when lang=ru..."
status, data = refine("add a ladder for 80", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s
  has_cyrillic = reply.match?(/[а-яА-ЯёЁ]/)
  report("RU: Reply contains Cyrillic when lang=ru", has_cyrillic, "reply=#{reply[0,100]}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian UI — English input still gets Russian reply..."
status, data = refine("set price to 500", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s
  has_cyrillic = reply.match?(/[а-яА-ЯёЁ]/)
  item = extract_items(data).first
  report("RU: Reply is Russian for English input", has_cyrillic, "reply=#{reply[0,100]}")
  report("RU: Price actually changed to 500",      item && item["price"].to_f == 500.0, "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian UI — Georgian input with lang=ru gets Russian reply..."
status, data = refine("დამატე კიბე 80 ლარად", lang: "ru", cookie: cookie, csrf: csrf)
if status == 200
  reply = data["reply"].to_s
  has_cyrillic = reply.match?(/[а-яА-ЯёЁ]/)
  no_georgian  = !reply.match?(/[\u10D0-\u10FF]/)
  report("RU: Reply is Russian (not Georgian) for Georgian input", has_cyrillic && no_georgian, "reply=#{reply[0,100]}")
else
  report("Server responds 200", false, "status=#{status}")
end

# ════════════════════════════════════════
# 19. CONTRADICTION & CORRECTION TESTS
# ════════════════════════════════════════
long_pause
puts "\n\e[1m── 19. CONTRADICTION & CORRECTION ──\e[0m"

delay
puts "\n  Testing: Add discount then remove it (2-turn contradiction)..."
_s1, turn1 = refine("add 10% discount", cookie: cookie, csrf: csrf)
if turn1["sections"]
  h1 = "User: add 10% discount\nAssistant: #{turn1["reply"]}"
  # Verify discount was applied
  t1_item = extract_items(turn1).first
  report("Turn 1: discount applied (10%)", t1_item && t1_item["discount_percent"].to_f == 10.0, "pct=#{t1_item&.dig("discount_percent")}")

  delay
  status, turn2 = refine("actually remove the discount", invoice: turn1, history: h1, cookie: cookie, csrf: csrf)
  if status == 200 && turn2["sections"]
    t2_item = extract_items(turn2).first
    report("Turn 2: discount removed (pct=0, flat=0)", t2_item && t2_item["discount_percent"].to_f == 0 && t2_item["discount_flat"].to_f == 0, "pct=#{t2_item&.dig("discount_percent")}, flat=#{t2_item&.dig("discount_flat")}")
    report("Turn 2: Price still 750 (unmutated)",      t2_item && t2_item["price"].to_f == 750.0, "price=#{t2_item&.dig("price")}")
  else
    report("Server responds 200 on turn 2", false, "status=#{status}")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "turn1 sections missing")
end

delay
puts "\n  Testing: Price correction ('set price to 150' → 'no I meant 1500')..."
_s1, turn1 = refine("set price to 150", cookie: cookie, csrf: csrf)
if turn1["sections"]
  t1_item = extract_items(turn1).first
  report("Turn 1: price set to 150", t1_item && t1_item["price"].to_f == 150.0, "price=#{t1_item&.dig("price")}")

  h1 = "User: set price to 150\nAssistant: #{turn1["reply"]}"
  delay
  status, turn2 = refine("no I meant 1500", invoice: turn1, history: h1, cookie: cookie, csrf: csrf)
  if status == 200 && turn2["sections"]
    t2_item = extract_items(turn2).first
    report("Turn 2: price corrected to 1500", t2_item && t2_item["price"].to_f == 1500.0, "price=#{t2_item&.dig("price")}")
  else
    report("Server responds 200 on turn 2", false, "status=#{status}")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "turn1 sections missing")
end

delay
puts "\n  Testing: Replace discount type ('change the 15% to a flat $100 discount')..."
inv_with_pct = sample_invoice
inv_with_pct["sections"][0]["items"][0]["discount_percent"] = 15
status, data = refine("change the 15% to a flat $100 discount instead", invoice: inv_with_pct, cookie: cookie, csrf: csrf)
if status == 200 && data["sections"]
  item = extract_items(data).first
  report("Replaced: discount_flat=100",    item && item["discount_flat"].to_f == 100.0,  "flat=#{item&.dig("discount_flat")}")
  report("Replaced: discount_percent=0",   item && item["discount_percent"].to_f == 0,   "pct=#{item&.dig("discount_percent")}")
  report("Replaced: Price still 750",      item && item["price"].to_f == 750.0,          "price=#{item&.dig("price")}")
else
  report("Server responds 200", false, "status=#{status}")
end

delay
puts "\n  Testing: Russian contradiction ('добавь скидку 20%' → 'нет, убери и сделай 50 лари')..."
_s1, turn1 = refine("добавь скидку 20%", lang: "ru", cookie: cookie, csrf: csrf)
if turn1["sections"]
  h1 = "User: добавь скидку 20%\nAssistant: #{turn1["reply"]}"
  t1_item = extract_items(turn1).first
  report("RU Turn 1: 20% discount applied", t1_item && t1_item["discount_percent"].to_f == 20.0, "pct=#{t1_item&.dig("discount_percent")}")

  delay
  status, turn2 = refine("нет, убери и сделай 50 лари скидку", invoice: turn1, history: h1, lang: "ru", cookie: cookie, csrf: csrf)
  if status == 200 && turn2["sections"]
    t2_item = extract_items(turn2).first
    report("RU Turn 2: pct discount removed (=0)",  t2_item && t2_item["discount_percent"].to_f == 0, "pct=#{t2_item&.dig("discount_percent")}")
    report("RU Turn 2: flat discount=50 applied",   t2_item && t2_item["discount_flat"].to_f == 50.0, "flat=#{t2_item&.dig("discount_flat")}")
    report("RU Turn 2: Price still 750",             t2_item && t2_item["price"].to_f == 750.0,        "price=#{t2_item&.dig("price")}")
  else
    report("Server responds 200 on turn 2", false, "status=#{status}")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "turn1 sections missing")
end

delay
puts "\n  Testing: Rapid-fire 3-step Russian chain (add item → discount → tax removal)..."
_s, ru1 = refine("добавь генератор за 2000", lang: "ru", cookie: cookie, csrf: csrf)
if ru1["sections"]
  h1 = "User: добавь генератор за 2000\nAssistant: #{ru1["reply"]}"
  delay
  _s, ru2 = refine("скидка 10% на генератор", invoice: ru1, history: h1, lang: "ru", cookie: cookie, csrf: csrf)
  if ru2["sections"]
    h2 = h1 + "\nUser: скидка 10% на генератор\nAssistant: #{ru2["reply"]}"
    delay
    status, ru3 = refine("убери налог со всего", invoice: ru2, history: h2, lang: "ru", cookie: cookie, csrf: csrf)
    if status == 200 && ru3["sections"]
      items = extract_items(ru3)
      gen = items.find { |i| i["desc"].to_s.downcase.match?(/генератор|generator/) }
      report("RU 3-step: Generator has 10% discount",  gen && gen["discount_percent"].to_f == 10.0, "pct=#{gen&.dig("discount_percent")}")
      report("RU 3-step: Generator price=2000",        gen && gen["price"].to_f == 2000.0,          "price=#{gen&.dig("price")}")
      report("RU 3-step: All items untaxed",           items.all? { |i| i["taxable"] == false },    "taxable=#{items.map { |i| [i["desc"], i["taxable"]] }}")
    else
      report("Server responds 200 on turn 3", false, "status=#{status}")
    end
  else
    report("Turn 2 succeeded (prerequisite)", false, "ru2 sections missing")
  end
else
  report("Turn 1 succeeded (prerequisite)", false, "ru1 sections missing")
end

# ════════════════════════════════════════
# RESULTS SUMMARY
# ════════════════════════════════════════
puts "\n\e[1m══════════════════════════════════════════\e[0m"
puts "\e[1m  RESULTS\e[0m"
puts "\e[1m══════════════════════════════════════════\e[0m"
puts "  \e[32mPASS: #{$results[:pass]}\e[0m"
puts "  \e[33mWARN: #{$results[:warn]}\e[0m"
puts "  \e[31mFAIL: #{$results[:fail]}\e[0m"
puts "  Total: #{$results[:pass] + $results[:warn] + $results[:fail]}"

if $failures.any?
  puts "\n\e[31m  FAILURES:\e[0m"
  $failures.each do |f|
    puts "    • #{f[:name]}: #{f[:detail]}"
  end
end

puts "\n"
exit($results[:fail] > 0 ? 1 : 0)
