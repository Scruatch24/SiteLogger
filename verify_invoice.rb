# Verification Script for InvoiceGenerator
require_relative "config/environment"

puts "Running InvoiceGenerator Verification..."

# Mock structures
MockProfile = Struct.new(:business_name, :address, :phone, :email, :currency, :tax_rate, :invoice_style, :payment_instructions, :hourly_rate)
MockLog = Struct.new(:id, :client, :date, :due_date, :tasks, :time, :hourly_rate, :billing_mode, :currency, :tax_scope, :labor_taxable, :global_discount_flat, :global_discount_percent, :credits)

profile = MockProfile.new("Acme Corp", "123 Main St", "555-0199", "test@acme.com", "USD", 0.0, "professional", "Pay now", 100)

# =========================================================
# TEST A: Tax + Item Discount Logic
# =========================================================
puts "\n[TEST A] Item-level Tax + Discount"
# Item: Price 100, Discount 10%, Tax 10%.
# Calc: Discount = 10. Net = 90. Tax = 9.
item_a = {
  "desc" => "Test Item",
  "price" => 100.0,
  "qty" => 1,
  "taxable" => true,
  "tax_rate" => 10.0,
  "discount_percent" => 10.0
}
log_a = MockLog.new(1, "Client A", nil, nil,
  [ { "title" => "Materials", "items" => [ item_a ] } ].to_json,
  0, 0, "hourly", "USD", "all", false, 0, 0, []
)

gen_a = InvoiceGenerator.new(log_a, profile)
data_a = gen_a.instance_variable_get(:@billable_items).first
subtotal_a = gen_a.instance_variable_get(:@subtotal)
tax_a = gen_a.instance_variable_get(:@tax_amount)
discount_total_a = gen_a.instance_variable_get(:@item_discount_total)

puts "  Price (Gross): #{data_a[:price]} (Expected: 100.0) -> #{data_a[:price] == 100.0 ? 'PASS' : 'FAIL'}"
puts "  Item Discount: #{data_a[:item_discount_amount]} (Expected: 10.0) -> #{data_a[:item_discount_amount] == 10.0 ? 'PASS' : 'FAIL'}"
puts "  Subtotal: #{subtotal_a} (Expected: 100.0) -> #{subtotal_a == 100.0 ? 'PASS' : 'FAIL'}"
puts "  Tax Amount: #{tax_a} (Expected: 9.0) -> #{tax_a == 9.0 ? 'PASS' : 'FAIL'}"
puts "  Total Discount: #{discount_total_a} (Expected: 10.0) -> #{discount_total_a == 10.0 ? 'PASS' : 'FAIL'}"

# Check Render Order Flags
puts "  Has Tax Line? #{data_a[:computed_tax_amount] > 0} (Expected: true)"

# =========================================================
# TEST B: Subitems Only
# =========================================================
puts "\n[TEST B] Subitems Only (No tax/discount)"
item_b = {
  "desc" => "Simple Item",
  "price" => 50.0,
  "sub_categories" => [ "Bullet 1", "Bullet 2" ]
}
log_b = MockLog.new(2, "Client B", nil, nil,
  [ { "title" => "Labor", "items" => [ item_b ] } ].to_json,
  0, 0, "fixed", "USD", "none", false, 0, 0, []
)
gen_b = InvoiceGenerator.new(log_b, profile)
data_b = gen_b.instance_variable_get(:@billable_items).first
puts "  Item Discount: #{data_b[:item_discount_amount]} (Expected: 0.0) -> #{data_b[:item_discount_amount] == 0.0 ? 'PASS' : 'FAIL'}"
puts "  Computed Tax: #{data_b[:computed_tax_amount]} (Expected: 0.0) -> #{data_b[:computed_tax_amount] == 0.0 ? 'PASS' : 'FAIL'}"

# =========================================================
# TEST C: Multiple Credits
# =========================================================
puts "\n[TEST C] Multiple Credits"
credits = [
  { "amount" => 20.0, "reason" => "Loyalty" },
  { "amount" => 30.0, "reason" => "Damage" }
]
log_c = MockLog.new(3, "Client C", nil, nil, "[]", 0, 0, "hourly", "USD", "all", false, 0, 0, credits)

# We need to manually inject credits if use struct (ActiveRecord handles array conversion usually)
# The mock struct has credits member, verify code reads it.
gen_c = InvoiceGenerator.new(log_c, profile)
credits_data = gen_c.instance_variable_get(:@credits)
puts "  Credits Count: #{credits_data.size} (Expected: 2) -> #{credits_data.size == 2 ? 'PASS' : 'FAIL'}"
puts "  Credit 1 Amount: #{credits_data[0][:amount]} (Expected: 20.0)"
puts "  Credit 2 Amount: #{credits_data[1][:amount]} (Expected: 30.0)"

# =========================================================
# TEST D: Sanitization
# =========================================================
puts "\n[TEST D] Sanitization"
desc_raw = "Labor: I installed a valve"
sanitized = gen_c.sanitize_description(desc_raw)
puts "  Input: '#{desc_raw}'"
puts "  Output: '#{sanitized}' (Expected: 'Installation of a valve') -> #{sanitized == 'Installation of a valve' ? 'PASS' : 'FAIL'}"

desc_raw_2 = "Service - Hourly service fixed the leak"
sanitized_2 = gen_c.sanitize_description(desc_raw_2)
puts "  Input: '#{desc_raw_2}'"
puts "  Output: '#{sanitized_2}' (Expected: 'Repair of the leak') -> #{sanitized_2 == 'Repair of the leak' ? 'PASS' : 'FAIL'}"

# =========================================================
# TEST E: Rendering Logic Check (Dry Run)
# =========================================================
puts "\n[TEST E] Rendering logic dry-run"
begin
  gen_a.render
  puts "  Render call successful (no errors)"
rescue => e
  puts "  Render FAILED: #{e.message}"
  puts e.backtrace.take(5)
end

puts "\nVerification Complete."
