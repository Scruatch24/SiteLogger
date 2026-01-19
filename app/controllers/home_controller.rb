class HomeController < ApplicationController
  require "net/http"
  require "uri"
  require "json"
  require "base64"

  # This ensures @profile is loaded for every single page so the design doesn't crash
  before_action :set_profile

  def index
  end

  def history
    @logs = Log.order(created_at: :desc)
  end

  def settings
    # @profile is already set by the before_action
  end

  def profile
    # @profile is already set by the before_action
  end

  def save_profile
    # Consistent with save_settings but redirects to profile
    @profile.assign_attributes(profile_params)

    respond_to do |format|
      if @profile.save
        format.html { redirect_to profile_path, notice: "Profile saved successfully!" }
        format.json { render json: { success: true, message: "Profile saved successfully!" } }
      else
        format.html { render :profile, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def save_settings
    # We use the @profile set by before_action
    @profile.assign_attributes(profile_params)

    respond_to do |format|
      if @profile.save
        format.html { redirect_to settings_path, notice: "Profile saved successfully!" }
        format.json { render json: { success: true, message: "Profile saved successfully!" } }
      else
        format.html { render :settings, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def process_audio
    api_key = ENV["GEMINI_API_KEY"]
    is_manual_text = params[:manual_text].present?
    mode = @profile.billing_mode || "hourly"

    begin
      instruction = <<~PROMPT
        You are a STRICT speech-to-invoice data extractor.

        DO NOT:
        - Create reports or summaries
        - Rephrase or beautify text
        - Guess or infer missing data
        - Annotate values (no parentheses, no labels)
        - Force results if audio is unclear

        ONLY extract facts that were EXPLICITLY spoken.

        === ERROR HANDLING (CRITICAL) ===
        If you cannot understand the audio or extract meaningful work details, return ONLY:
        {"error": "Audio unclear - please try again"}

        Return an error if:
        - Audio is silent or has only background noise
        - Speech is unintelligible or too quiet
        - No work-related information is detected
        - Only random words with no context

        DO NOT return empty fields with fabricated data. Return an error instead.
        **CRITICAL**: If the user only mentions a credit or discount context (e.g., "apply $50 credit for overcharge"), DO NOT invent materials, expenses, or fees that were not explicitly mentioned. Only return exactly what was stated.

        === CATEGORY SYSTEM (CRITICAL) ===

        There are FOUR distinct categories. You MUST categorize each item correctly:

        1. LABOR/SERVICE (labor_service_items):
           - Work descriptions WITHOUT a separate price
           - These are tied to the main labor charge (hourly or fixed)
           - Examples: "repaired the sink", "electrical work", "installed flooring"
           - If someone says "2 hours plumbing work", the "plumbing work" goes here
           - **DEFAULT**: If LABOR time/price is detected but no specific work described, use "Work performed".
           - ONLY leave empty if no labor/time is present (e.g. credit-only).

        2. MATERIALS (materials):
           - PHYSICAL GOODS incorporated into the project or handed to client
           - These HAVE a price (unit_price)
           - Examples: "faucet $40", "pipes $15", "lumber", "wiring", "servers", "cables"
           - Tangible items the customer can touch

        3. EXPENSES (expenses):
           - PASS-THROUGH REIMBURSEMENTS - costs you paid to third parties
           - No profit made - just getting paid back what was spent
           - Usually NOT taxed (tax-exempt reimbursements)
           - Examples: "Uber $25", "hotel $150", "parking $10", "flight $300", "toll $5", "rental equipment $50"
           - Key words: travel, Uber, Lyft, taxi, hotel, lodging, parking, toll, mileage, gas, rental

        4. FEES (fees):
           - SURCHARGES that count as your income/revenue
           - Extra charges added to cover business costs or risks
           - Usually taxed as a service
           - Examples: "rush fee $50", "credit card fee 3%", "disposal fee $30", "admin fee $20", "service charge $15"
           - Key words: fee, charge, surcharge, rush, processing, admin, disposal, convenience

        === TAX SCOPE RULES ===
        - Available tokens: "labor", "materials_only", "fees_only", "expenses_only"
        - Examples:
          - "tax everything" → "labor,materials_only,fees_only,expenses_only"
          - "don't tax anything" → "none"
          - "tax labor and fees" → "labor,fees_only"
          - "don't tax the expenses" → (leave expenses_only out of the list)
          - "tax only the part" or "tax only the materials" → "materials_only"
          - "tax the valve" (when valve is a material) → "materials_only"
        - CRITICAL: When tax_scope includes a category token, the items in that category#{' '}
          MUST have "taxable": true in the output JSON. The dashboard uses this flag.

        === PRICING RULES ===
        - Extract prices even if phrased as "around $40", "costs $40"
        - unit_price/price must be a number (e.g. 40.0)

        === CURRENCY DETECTION ===
        - Extract "currency" ONLY if user explicitly mentions a currency NAME or CODE
        - Ignore symbols ($, €, £) attached to numbers
        - If no currency word → null

        === BILLING MODE ===
        - HOURLY: "X per hour", "X an hour", mentions of hours + rate
        - FIXED: "fixed price", "flat rate", "charge X for the job"
        - DEFAULT: #{mode.upcase}

        === TIME/HOURS RULES ===
        - Only extract time if duration words exist: hour, hours, minutes, half, quarter
        - "hour and a half" → 1.5
        - "45 minutes" → 0.75
        - IGNORE numbers for prices, quantities, addresses

        === LABOR HOURS vs FIXED PRICE ===
        - HOURS + RATE → billing_mode: "hourly", labor_hours: X, hourly_rate: Y
        - TOTAL for job → billing_mode: "fixed", fixed_price: X
        - NEVER calculate hours × rate

        === RATE MULTIPLIERS (CURRENT DEFAULT RATE: #{(@profile.hourly_rate.presence || 0)}) ===
        - If user implies a multiplier on their normal rate (e.g., "double my rate", "time and a half", "half price labor"):
        - CALCULATE the new rate based on the default rate provided above.
        - Example (Default 50): "Double rate" → hourly_rate: 100
        - Example (Default 100): "Half rate" → hourly_rate: 50
        - If no multiplier mentioned, return null for hourly_rate (use default).

        === DISCOUNT RULES ===
        - "off the labor", "off the work" → labor_discount_flat/percent
        - "off the total", "off the invoice", "off the bill" → global_discount_flat/percent
        - "off the [item]" → item discount
        - **IMPORTANT**: If the user says "X off the total" and mentions a similar number for a material (e.g., "Pipe for 20, take 20 off the total"), you MUST extract BOTH. Do not assume the second mention is just a repetition of the first.
        - **DEFAULT**: If unspecified where "off" applies but "total" is mentioned anywhere in that context, use global_discount.
        - If user explicitly says "before tax" or "pre-tax discount" → discount_tax_mode: "pre_tax"
        - If user explicitly says "after tax" or "post-tax discount" → discount_tax_mode: "post_tax"
        - **default** to "post_tax" unless user specifies "pre-tax" or "before tax".

        === PROFESSIONAL INVOICE TONE ===
        You are an AI assistant that generates PROFESSIONAL INVOICE DATA.
        - Your output will be displayed directly on a formal invoice.
        - **GLOBAL RULE**: Rephrase ALL casual user input (labor descriptions, material names, credit reasons) into professional business terminology.
        - **Avoid** first-person phrases like "I did...", "We installed...". Use "Installation of...", "Repair of...", etc.
        - EXAMPLES:
          - Labor: "I fixed the leak" → "Leak repair service"
          - Labor: "Changed the bulb" → "Light bulb replacement"
          - Labor: "looked at the breaker" → "Circuit breaker inspection"
          - Material: "bought some generic pipe" → "PVC Piping"
          - Credit: "I overcharged them last time" → "Previous balance adjustment"
          - Credit: "My fault so I'm giving them 20 bucks" → "Courtesy credit"
          - Credit: "They prepaid" → "Prepayment applied"

        === CREDIT RULES (IMPORTANT: CREDIT ≠ DISCOUNT) ===
        Credit is money owed TO the customer from a PAST event. Discount is a reduction on the CURRENT invoice.
        - **High confidence**: "credit", "store credit", "warranty credit", "apply credit", "their credit"
        - **Medium confidence**: "overcharged", "I overcharged them" (use context to confirm it's a credit, not just a statement)
        - Extract: credit_flat (amount), credit_reason (why the credit exists)
        - **CRITICAL**: If credit_flat is present, ALWAYS extract a credit_reason. If none is explicitly stated, infer the most logical one (e.g. "customer credit").
        - **REPHRASING**:
          - "I overcharged them 20 last time" → credit_flat: 20, credit_reason: "Previous balance adjustment"
          - "They have a deposit of 100" → credit_flat: 100, credit_reason: "Deposit applied"
          - "Credit for the mistake" → credit_flat: 50, credit_reason: "Service adjustment"
        - Examples:
          - "Apply their $50 credit" → credit_flat: 50, credit_reason: "Customer credit", currency: "USD"
          - "Warranty credit of 30 dollars" → credit_flat: 30, credit_reason: "Warranty credit", currency: "USD"
          - "I overcharged them 20 last time" → credit_flat: 20, credit_reason: "Previous balance adjustment"

        - **CRITICAL**: Only include items in materials, expenses, or fees if explicitly mentioned. If only a credit/discount is mentioned, leave other sections empty.

        OUTPUT STRICT JSON ONLY:

        {
          "client": "",
          "address": "",
          "labor_hours": "",
          "fixed_price": "",
          "hourly_rate": null,
          "labor_tax_rate": null,
          "labor_taxable": null,
          "labor_discount_flat": "",
          "labor_discount_percent": "",
          "global_discount_flat": "",
          "global_discount_percent": "",
          "discount_tax_mode": null,
          "credit_flat": "",
          "credit_reason": "",
          "currency": null,
          "billing_mode": null,
          "tax_scope": "",
          "labor_service_items": [
            { "desc": "" }
          ],
          "materials": [
            { "name": "", "qty": "", "unit_price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "" }
          ],
          "expenses": [
            { "desc": "", "price": "", "taxable": false, "tax_rate": null, "discount_flat": "", "discount_percent": "" }
          ],
          "fees": [
            { "desc": "", "price": "", "taxable": true, "tax_rate": null, "discount_flat": "", "discount_percent": "" }
          ],
          "due_days": null,
          "due_date": null,
          "raw_summary": ""
        }
      PROMPT

      if is_manual_text
        prompt_parts = [ {
          text: "#{instruction}\nTEXT:\n#{params[:manual_text]}"
        } ]
      else
        audio = params[:audio]
        return render json: { error: "No audio" }, status: 400 unless audio

        audio_data = Base64.strict_encode64(audio.read)
        prompt_parts = [
          { text: instruction },
          { inline_data: { mime_type: audio.content_type, data: audio_data } }
        ]
      end

      uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      req.body = { contents: [ { parts: prompt_parts } ] }.to_json

      res = http.request(req)
      body = JSON.parse(res.body)
      raw = body.dig("candidates", 0, "content", "parts", 0, "text")

      return render json: { error: "AI failed" }, status: 500 unless raw

      cleaned = raw.gsub(/```json|```/, "")
      json = JSON.parse(cleaned) rescue nil
      return render json: { error: "Invalid AI output" }, status: 422 unless json

      if json["error"]
        return render json: { error: json["error"] }, status: 422
      end

      Rails.logger.info "AI_DEBUG_RAW: #{json}"

      # ---------- NORMALIZATION ----------
      def clean_num(val)
        return "" if val.blank?
        # Remove anything that isn't a digit, decimal point, or negative sign
        stripped = val.to_s.gsub(/[^0-9.-]/, "")
        return "" if stripped.blank?
        f = stripped.to_f
        (f % 1 == 0) ? f.to_i.to_s : f.to_s
      end

      hours = clean_num(json["labor_hours"])
      price = clean_num(json["fixed_price"])
      json["hourly_rate"] = clean_num(json["hourly_rate"]) if json["hourly_rate"]
      json["labor_hours"] = hours
      json["fixed_price"] = price

      effective_tax_rate = clean_num(json["labor_tax_rate"]).presence || @profile.tax_rate.to_s
      json["labor_tax_rate"] = effective_tax_rate

      # Pass Labor & Global Discounts
      json["labor_discount_flat"] = clean_num(json["labor_discount_flat"])
      json["labor_discount_percent"] = clean_num(json["labor_discount_percent"])
      json["global_discount_flat"] = clean_num(json["global_discount_flat"])
      json["global_discount_percent"] = clean_num(json["global_discount_percent"])

      # Pass Credit
      json["credit_flat"] = clean_num(json["credit_flat"])
      json["credit_reason"] = json["credit_reason"].to_s.strip.presence&.upcase_first

      # Pass Discount Tax Mode (pre_tax/post_tax if explicitly mentioned, otherwise nil for profile default)
      json["discount_tax_mode"] = json["discount_tax_mode"] if [ "pre_tax", "post_tax" ].include?(json["discount_tax_mode"])

      # ===== FALLBACK: Extract discount from raw_summary if AI missed it =====
      json["raw_summary"] ||= params[:manual_text]
      raw_text = json["raw_summary"].to_s.downcase
      Rails.logger.info "FALLBACK_DEBUG: raw_text=#{raw_text}"

      # Convert word numbers to digits
      word_to_num = { "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
                      "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10,
                      "eleven" => 11, "twelve" => 12, "fifteen" => 15, "twenty" => 20,
                      "twenty-five" => 25, "thirty" => 30, "forty" => 40, "fifty" => 50 }
      word_to_num.each { |word, num| raw_text = raw_text.gsub(/\b#{word}\b/i, num.to_s) }

      # CORRECTION: Move Labor Discount to Global if context implies Total
      # Aggressively move if "total" is mentioned and global is empty
      if json["global_discount_flat"].blank? && json["global_discount_percent"].blank?
         total_regex = /(off|discount).*?(total|invoice|bill)/i

         if raw_text.match(total_regex)
            # Find the value to move. Check labor or even misclassified items if they match the phrase context
            if json["labor_discount_flat"].present? || json["labor_discount_percent"].present?
               Rails.logger.info "CORRECTION RULES: Moving Labor Discount to Global (Context: '#{raw_text}')"
               json["global_discount_flat"] = json["labor_discount_flat"]
               json["global_discount_percent"] = json["labor_discount_percent"]
               json["labor_discount_flat"] = ""
               json["labor_discount_percent"] = ""
            end
         end
      end

      # ===== FALLBACK: Extract discount from raw_summary if BOTH are missing =====
      if json["labor_discount_percent"].blank? && json["global_discount_percent"].blank?
        # Check if discount is item-specific (e.g. "discount on the bulb")
        is_item_specific = raw_text.match(/discount\s+(on|for)\s+(the\s+)?\w+/i) ||
                           (raw_text.match(/off\s+(the\s+)?\w+/i) && !raw_text.match(/off\s+(the\s+)?(labor|work|service|total|invoice|bill)/i))

        is_global = raw_text.match(/(total|invoice|bill)/i)

        unless is_item_specific
          # Percentage extraction: "20 percent off/discount", "discount of 20%"
          if match = raw_text.match(/(\d+)\s*(percent|%)\s*(discount|off)/i) ||
                     raw_text.match(/discount\s*(of)?\s*(\d+)\s*(percent|%)/i)
            val = match[1] || match[2]
            if is_global
              json["global_discount_percent"] = val
            else
              json["labor_discount_percent"] = val
            end
          end
        end
      end

      # If labor_discount_flat is empty, try to extract from raw_text
      if json["labor_discount_flat"].blank? && json["global_discount_flat"].blank?
        amount_pattern = "(?:\\$)?(\\d+(\\.\\d+)?)\\s*(?:dollars|bucks)?"

        is_item_specific = (raw_text.match(/#{amount_pattern}\s*(off|discount)\s+(on|for)?\s*(the\s+)?\w+/i) &&
                           !raw_text.match(/#{amount_pattern}\s*(off|discount)\s+(on|for)?\s*(the\s+)?(labor|work|service|total|invoice|bill)/i))

        is_global = raw_text.match(/(total|invoice|bill)/i)

        unless is_item_specific
          # Flat extraction: "$20 off", "20 off", "20 dollars discount"
          if match = raw_text.match(/#{amount_pattern}\s*(off|discount)/i) ||
                     raw_text.match(/(?:off|discount)\s*(?:of)?\s*#{amount_pattern}/i)
             val = match[1]
             if is_global
               json["global_discount_flat"] = val
             else
               json["labor_discount_flat"] = val
             end
          end
        end
      end




      # PASS labor_taxable through if provided (null means use scope default)
      l_taxable = json["labor_taxable"]
      json["labor_taxable"] = if l_taxable == true || l_taxable == "true"
        true
      elsif l_taxable == false || l_taxable == "false"
        false
      else
        nil
      end

      effective_tax_scope =
        json["tax_scope"].to_s.strip.presence ||
          @profile.tax_scope.to_s.strip.presence ||
          "total"

      json["tax_scope"] = effective_tax_scope

      # Use AI-detected billing_mode if provided, otherwise fall back to profile
      effective_mode = json["billing_mode"].to_s.strip.presence || mode
      json["billing_mode"] = effective_mode

      json["time"] =
        if effective_mode == "fixed"
          price.presence || ""
        else
          hours.presence || ""
        end

      json["sections"] = []

      # ... (rest of normalization)

      # LABOR/SERVICE items (no price - tied to labor charge)
      if json["labor_service_items"]&.any?
        json["sections"] << {
          title: "Labor/Service",
          items: json["labor_service_items"].map do |item|
            if item.is_a?(Hash)
              { desc: item["desc"].to_s.strip.upcase_first }
            else
              { desc: item.to_s.strip.upcase_first }
            end
          end
        }
      end

      # MATERIALS (physical goods with price)
      if json["materials"]&.any?
        json["sections"] << {
          title: "Materials",
          items: json["materials"].map do |m|
            {
              desc: m["name"].to_s.strip.upcase_first,
              qty: clean_num(m["qty"].presence || "1"),
              price: clean_num(m["unit_price"]),
              taxable: m["taxable"],
              tax_rate: m["tax_rate"],
              discount_flat: clean_num(m["discount_flat"]),
              discount_percent: clean_num(m["discount_percent"])
            }
          end
        }
      end

      # EXPENSES (pass-through reimbursements)
      if json["expenses"]&.any?
        json["sections"] << {
          title: "Expenses",
          items: json["expenses"].map do |e|
            {
              desc: e["desc"].to_s.strip.upcase_first,
              price: clean_num(e["price"]),
              taxable: e["taxable"].nil? ? false : e["taxable"], # Default to not taxable
              tax_rate: e["tax_rate"],
              discount_flat: clean_num(e["discount_flat"]),
              discount_percent: clean_num(e["discount_percent"])
            }
          end
        }
      end

      # FEES (surcharges - income)
      if json["fees"]&.any?
        json["sections"] << {
          title: "Fees",
          items: json["fees"].map do |f|
            {
              desc: f["desc"].to_s.strip.upcase_first,
              price: clean_num(f["price"]),
              taxable: f["taxable"].nil? ? true : f["taxable"], # Default to taxable
              tax_rate: f["tax_rate"],
              discount_flat: clean_num(f["discount_flat"]),
              discount_percent: clean_num(f["discount_percent"])
            }
          end
        }
      end

      json.slice!("client", "time", "raw_summary", "sections", "tax_scope", "billing_mode", "currency", "hourly_rate", "labor_tax_rate", "labor_taxable", "labor_discount_flat", "labor_discount_percent", "global_discount_flat", "global_discount_percent", "credit_flat", "credit_reason", "discount_tax_mode", "due_days", "due_date")

      render json: json

    rescue => e
      render json: { error: e.message }, status: 500
    end
  end


  private

  def set_profile
    @profile = Profile.first || Profile.new
  end

  def profile_params
    # FIXED: Added :billing_mode to the permitted list
    params.require(:profile).permit(
      :business_name,
      :phone,
      :email,
      :address,
      :tax_id,
      :hourly_rate,
      :tax_rate,
      :tax_scope,
      :payment_instructions,
      :billing_mode,
      :currency,
      :invoice_style,
      :discount_tax_rule,
      :logo
    )
  end
end
