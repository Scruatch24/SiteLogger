require 'json'
require 'base64'

# Mock Profile
class Profile
  attr_accessor :hourly_rate, :tax_rate, :billing_mode, :tax_scope
  def initialize
    @hourly_rate = 100
    @tax_rate = 10
    @tax_scope = "total"
    @billing_mode = "hourly"
  end
end

@profile = Profile.new

# HELPER METHODS (Copied from home_controller.rb)
def clean_num(val)
  return nil if val.nil? || (val.is_a?(String) && val.strip.empty?)
  stripped = val.to_s.gsub(/[^0-9.-]/, "")
  return nil if stripped.empty?
  f = stripped.to_f
  (f % 1 == 0) ? f.to_i : f
end

def to_bool(val)
  return false if val.nil?
  str = val.to_s.downcase.strip
  [ "true", "1", "yes", "on" ].include?(str)
end

# SIMULATED JSON INPUT (From AI)
json_input = {
  "labor_hours" => 2,
  "fixed_price" => nil,
  "hourly_rate" => nil,
  "labor_tax_rate" => 10,
  "labor_taxable" => true,
  "labor_discount_flat" => nil,
  "labor_discount_percent" => 5, # GLOBAL LABOR DISCOUNT 5%
  "global_discount_flat" => nil,
  "global_discount_percent" => nil,
  "discount_tax_mode" => "pre_tax",
  "priority" => "low", # junk
  "credits" => [],
  "currency" => "USD",
  "billing_mode" => "hourly",
  "tax_scope" => "total",
  "labor_service_items" => [
    { "desc" => "Visit 1", "hours" => 1.5, "rate" => 90, "sub_categories" => [ "Sensor" ] },
    { "desc" => "Visit 2", "hours" => 0.5, "rate" => 90, "sub_categories" => [] }
  ],
  "materials" => [],
  "expenses" => [],
  "fees" => []
}

# LOGIC TO TEST (Partial extract from home_controller.rb)
json = json_input
json["sections"] = []

if json["labor_service_items"]&.any?
    json["sections"] << {
      title: "Labor/Service",
      items: json["labor_service_items"].each_with_index.map do |item, idx|
        if item.is_a?(Hash)
          item_mode = item["mode"] || json["billing_mode"] || "hourly"

          # Logic from controller
          inherit_flat_discount = json["labor_service_items"].size == 1
          inherit_percent_discount = true

          {
            desc: item["desc"].to_s.strip,
            discount_flat: clean_num(item["discount_flat"] || (inherit_flat_discount && json["labor_discount_flat"] ? json["labor_discount_flat"] : "")),
            discount_percent: clean_num(item["discount_percent"] || (inherit_percent_discount && json["labor_discount_percent"] ? json["labor_discount_percent"] : ""))
          }
        end
      end
    }
end

puts JSON.pretty_generate(json["sections"])

# VALIDATION
items = json["sections"][0][:items]
passed = true
items.each do |item|
  if item[:discount_percent] != 5
    puts "FAILED: Item #{item[:desc]} has discount_percent #{item[:discount_percent]}, expected 5"
    passed = false
  end
end

if passed
  puts "SUCCESS: All labor items inherited the 5% discount."
else
  puts "FAILURE: Discount propagation incorrect."
end
