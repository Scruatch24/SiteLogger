
# Simulation of HomeController Logic
raw_text = "Labor was three hours at seventy. Pipe for twenty, plate for nine. Oh and take twenty off the total."
raw_text = raw_text.downcase

# Word to Num simulation
word_to_num = { "one" => 1, "two" => 2, "three" => 3, "four" => 4, "twenty" => 20 }
word_to_num.each { |word, num| raw_text = raw_text.gsub(/\b#{word}\b/i, num.to_s) }

puts "Processed Text: #{raw_text}"

# Simulation of Params
json = {
  "global_discount_flat" => "",
  "global_discount_percent" => ""
}

# The Logic
if json["global_discount_flat"].empty? && json["global_discount_percent"].empty? &&
   raw_text.match(/(total|invoice|bill)/i)

   puts "Context 'Total' detected."

   # Fallback Force Regex
   force_match = raw_text.match(/(\d+(?:\.\d+)?)\s*(?:off|discount)/i) ||
                 raw_text.match(/(?:off|discount|minus|less|remove|deduct|take|apply)\s*(\d+(?:\.\d+)?)/i)

   if force_match
      val = force_match[1]
      puts "SUCCESS: Force Global Discount = #{val}"
   else
      puts "FAILURE: No force match found."
   end
else
   puts "FAILURE: Context 'Total' NOT detected or Discount already present."
end
