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

  def save_settings
    # We use the @profile set by before_action
    @profile.assign_attributes(profile_params)

    if @profile.save
      redirect_to settings_path, notice: "Profile saved successfully!"
    else
      render :settings, status: :unprocessable_entity
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
        - Create reports
        - Create summaries
        - Create section titles
        - Rephrase or beautify text
        - Guess or infer missing data
        - Annotate values (no parentheses, no labels)

        ONLY extract facts that were EXPLICITLY spoken.

        TAX SCOPE RULES:
        - Extract "tax_scope" as a comma-separated string of tokens ONLY if explicitly stated.
        - If not explicitly stated → null (let front-end decide default).
        - Available tokens:
          - "labor" (tax service/time)
          - "tasks_only" (tax tasks/items in task sections)
          - "materials_only" (tax materials/items in material sections)
        - Examples:
          - "tax everything" → "labor,tasks_only,materials_only"
          - "don't tax anything" → "none" (or empty string/null)
          - "only tax materials and labor" → "labor,materials_only"
          - "10% discount on labor" → "labor_discount_percent": "10"
          - "take $20 off the labor" → "labor_discount_flat": "20"
          - "Give the customer a ten percent discount on labor" → "labor_discount_percent": "10"
          - "apply a 5% discount" → "labor_discount_percent": "5"

        PER-ITEM TAXABLE OVERRIDES (CRITICAL):
        - If user says "only [specific item] is taxable":
          - Set "taxable": true for that specific item.
          - Set "taxable": false for ALL OTHER items (tasks and materials).
        - If user says "No tax on [specific item]":
          - Set "taxable": false for that specific item.
          - Do NOT change the global "tax_scope".
        - If no "only" constraint:
          - Set "taxable": null (allow default logic).

        PRICING RULES:
        - Extract prices even if phrased as "around $40", "should be $40", "costs $40".
        - unit_price must be a number (e.g. 40.0).

        CURRENCY DETECTION (CRITICAL - EXPLICIT ONLY):
        - Extract "currency" ONLY if user explicitly mentions a currency NAME or CODE.
        - IGNORE currency symbols (like "$", "€", "£") attached to numbers, as these may be auto-formatted.
        - Keyword → Code mapping:
          - "euros", "EUR" → "EUR"
          - "pounds", "GBP", "sterling" → "GBP"
          - "yen", "JPY" → "JPY"
          - "dollars", "USD", "bucks" → "USD"
          - "rubles", "RUB" → "RUB"
          - "dirhams", "AED" → "AED"
        - If no currency word is present → null (use profile default).
        - DO NOT guess from price numbers alone.

        QUANTITY & PRICE RULES:
        - If user mentions quantity + price (e.g., "two outlets at twenty each", "added 5 valves at 10 bucks"):
          - Set "materials" name: "outlets" / "valves"
          - Set "qty": "2" / "5"
          - Set "unit_price": "20" / "10"
        - Always look for phrases like "at X each", "each was X", "cost X per piece".

        BILLING MODE OVERRIDE (EXPLICIT ONLY):
        - Extract "billing_mode" based on how user describes the rate.
        - HOURLY patterns (→ "hourly"):
          - "X per hour", "X an hour", "at X an hour", "hourly rate", "by the hour"
          - Any mention of "hours" + rate = hourly
        - FIXED patterns (→ "fixed"):
          - "fixed price", "flat rate", "one-time fee", "total cost", "charge X for the job"
        - If no explicit billing keywords → null (use profile default).

        PER-ITEM TAX RATES:
        - If user mentions a specific tax rate for an item, set "tax_rate" on that item.
        - Example: "15% tax on the paint" → { "name": "paint", "tax_rate": 15 }
        - If no rate mentioned → null (use global default).

        AUDIO VALIDATION:
        - If audio is silent or unclear → return {"error":"Audio unclear"}
        - If no work details → return {"error":"No work details detected"}

        TIME RULES (CRITICAL):
        - Only extract time if duration words exist:
          ("hour", "hours", "minutes", "half", "quarter")
        - Convert:
          "hour and a half" → 1.5
          "one and a half hours" → 1.5
          "hour fifteen" → 1.25
          "45 minutes" → 0.75
        - IGNORE numbers related to:
          prices, materials, quantities, addresses
        - If unsure → return empty string

        LABOR HOURS vs FIXED PRICE (CRITICAL - DO NOT CALCULATE):
        - If user mentions HOURS + RATE (e.g., "1.5 hours at 60 an hour"):
          - Set "billing_mode": "hourly"
          - Set "labor_hours": "1.5" (just the duration, NOT a total)
          - Set "hourly_rate": "60" (the rate mentioned per hour)
          - Leave "fixed_price": ""
        - If user mentions a TOTAL for the job (e.g., "charged 200 for the job"):
          - Set "billing_mode": "fixed"
          - Set "fixed_price": "200"
          - Leave "labor_hours": ""
        - NEVER calculate hours × rate. Just extract raw values.
        - If user mentions a specific TAX RATE for labor (e.g., "tax of seventeen to the labor"):
          - Set "labor_tax_rate": "17"
          - Set "labor_taxable": true
        - Otherwise leave "labor_tax_rate": null.
        - LABOR TAXABLE OVERRIDE:
          - If user says "Add tax to the labor" or similar → Set "labor_taxable": true.
          - If user says "no tax on labor" or "labor is tax-free" → Set "labor_taxable": false.
          - If user says "no tax" GLOBALLY (without mentioning a specific item) → Set "labor_taxable": false and "tax_scope": "none".
          - If no mention → leave "labor_taxable": null.

        DISCOUNT RULES - LABOR (CRITICAL - DO NOT IGNORE):
        - Extract discounts for labor/work/service from ANY phrasing:
          - "X% discount" → labor_discount_percent: "X"
          - "X percent off" → labor_discount_percent: "X"
          - "give them X% off" → labor_discount_percent: "X"
          - "give the customer a X percent discount" → labor_discount_percent: "X"
          - "$X off labor" → labor_discount_flat: "X"
        - Convert written numbers: "ten" → 10, "twenty" → 20, "fifty" → 50
        - If no discount → leave empty strings.

        DISCOUNT RULES - ITEMS (CRITICAL):
        - If user mentions a discount for a specific item:
          - Set "discount_percent" or "discount_flat" on that item.

        DEFAULT BILLING MODE: #{mode.upcase}

        MATERIAL VS TASK RULES:
        - DUAL ENTRY (CRITICAL): If the user mentions an action AND a physical part (e.g., "replaced kitchen faucet, faucet was 40"), you MUST list the action in "tasks" (e.g., "replaced kitchen faucet") AND the part in "materials" (e.g., "kitchen faucet").
        - WORK DESCRIPTIONS (CRITICAL): Always extract the specific description of the work (e.g., "electrical work", "plumbing", "repaired outlet") into the "tasks" array, even if it is the work for which the labor hours were charged.
          - Example: "3 hours electrical work" → labor_hours: 3, tasks: ["electrical work"].
        - PRICE MAPPING:
          - If a price is linked to an action/work (e.g., "the task was 40", "installation cost 20"), put the price in that item's "price" field in "tasks".
          - If a price is linked to a physical part (e.g., "the faucet was 40", "material cost 50"), put it in "unit_price" in "materials".
          - If the user says "[Item] was 40" generally, default to "materials".
        - REDUNDANCY RULE: Do NOT add a task CALLED "Labor" or "Work" if labor_hours or fixed_price is extracted. Use the *specific description* instead or leave empty if only generic (e.g., "worked for 2 hours").
        - If the only mention is generic (e.g., "worked for 2 hours"), leave "tasks": [].

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
          "currency": null,
          "billing_mode": null,
          "tax_scope": "",
          "materials": [
            { "name": "", "qty": "", "unit_price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "" }
          ],
          "tasks": [
            { "desc": "", "price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "" }
          ],
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
        f = val.to_s.to_f
        (f % 1 == 0) ? f.to_i.to_s : f.to_s
      end

      hours = clean_num(json["labor_hours"])
      price = clean_num(json["fixed_price"])
      json["hourly_rate"] = clean_num(json["hourly_rate"]) if json["hourly_rate"]
      json["labor_hours"] = hours
      json["fixed_price"] = price

      effective_tax_rate = clean_num(json["labor_tax_rate"]).presence || @profile.tax_rate.to_s
      json["labor_tax_rate"] = effective_tax_rate

      # Pass Labor Discounts
      json["labor_discount_flat"] = clean_num(json["labor_discount_flat"])
      json["labor_discount_percent"] = clean_num(json["labor_discount_percent"])

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

      Rails.logger.info "FALLBACK_DEBUG_PROCESSED: '#{raw_text}' | Current Percent: '#{json["labor_discount_percent"]}'"

      # If labor_discount_percent is empty, try to extract from raw_text
      if json["labor_discount_percent"].blank?
        # Match patterns like "10 percent discount", "10% off", "discount of 10%"
        if match = raw_text.match(/(\d+)\s*(percent|%)\s*(discount|off)/i)
          json["labor_discount_percent"] = match[1]
          Rails.logger.info "FALLBACK_EXTRACTED: labor_discount_percent = #{match[1]}"
        elsif match = raw_text.match(/discount\s*(of)?\s*(\d+)\s*(percent|%)/i)
          json["labor_discount_percent"] = match[2]
          Rails.logger.info "FALLBACK_EXTRACTED: labor_discount_percent = #{match[2]}"
        end
      end

      # If labor_discount_flat is empty, try to extract from raw_text
      if json["labor_discount_flat"].blank?
        if match = raw_text.match(/\$(\d+(\.\d+)?)\s*(off|discount)/i)
          json["labor_discount_flat"] = match[1]
          Rails.logger.info "FALLBACK_EXTRACTED: labor_discount_flat = #{match[1]}"
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

      if json["tasks"].any?
        json["sections"] << {
          title: "Tasks",
          items: json["tasks"].map do |t|
            if t.is_a?(Hash)
              {
                desc: t["desc"],
                price: clean_num(t["price"]),
                taxable: t["taxable"],
                tax_rate: t["tax_rate"],
                discount_flat: clean_num(t["discount_flat"]),
                discount_percent: clean_num(t["discount_percent"])
              }
            else
              { desc: t }
            end
          end
        }
      end

      if json["materials"].any?
        json["sections"] << {
          title: "Materials",
          items: json["materials"].map do |m|
            {
              desc: m["name"],
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

      json.slice!("client", "time", "raw_summary", "sections", "tax_scope", "billing_mode", "currency", "hourly_rate", "labor_tax_rate", "labor_taxable", "labor_discount_flat", "labor_discount_percent")

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
      :billing_mode, # <--- This allows the "Fixed vs Hourly" toggle to save
      :currency,
      :logo
    )
  end
end
