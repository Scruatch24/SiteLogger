class HomeController < ApplicationController
  helper :logs
  require "net/http"
  require "uri"
  require "json"
  require "base64"



  def index
    @categories = if user_signed_in?
      # Ensure Favorites category exists and has correct styling (Self-Healing)
      fav = current_user.categories.where("name ILIKE ?", "Favorites").first_or_initialize
      if fav.new_record? || fav.name != "Favorites" || fav.color != "#EAB308" || fav.icon != "star"
        fav.update(name: "Favorites", color: "#EAB308", icon: "star", icon_type: "premade")
      end

      current_user.categories.order(name: :asc)
    else
      []
    end
  end

  def history
    @logs = if user_signed_in?
      current_user.logs.eager_load(:categories).order("logs.pinned DESC NULLS LAST, logs.pinned_at DESC NULLS LAST, logs.created_at DESC")
    else
      Log.where(user_id: nil).eager_load(:categories).order("logs.pinned DESC NULLS LAST, logs.pinned_at DESC NULLS LAST, logs.created_at DESC")
    end

    @categories = if user_signed_in?
      # Ensure Favorites category exists and has correct styling (Self-Healing)
      fav = current_user.categories.where("name ILIKE ?", "Favorites").first_or_initialize
      if fav.new_record? || fav.name != "Favorites" || fav.color != "#EAB308" || fav.icon != "star"
        fav.update(name: "Favorites", color: "#EAB308", icon: "star", icon_type: "premade")
      end

      current_user.categories.preload(:logs).order(name: :asc)
    else
      []
    end
  end

  def settings
    # @profile is already set by the before_action
  end

  def profile
    @is_new_profile = !@profile.persisted?
  end

  def save_profile
    if @profile.guest?
      return render json: { success: false, errors: [ "Guests cannot save profile settings. Please sign up to unlock." ] }, status: :forbidden
    end

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
    if @profile.guest?
      return render json: { success: false, errors: [ "Guests cannot save settings. Please sign up to unlock." ] }, status: :forbidden
    end

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
    limit = @profile.char_limit

    # Server-side Audio Duration Check
    if !is_manual_text && params[:audio_duration].present? && params[:audio_duration].to_f < 1.0
       return render json: { error: "Audio too short. Please speak longer." }, status: :unprocessable_entity
    end

    # Character Limit Check
    current_length = params[:manual_text].to_s.length
    if current_length >= limit
      return render json: {
        error: "Your transcript is already at the character limit (#{limit}). Upgrade to add more text."
      }, status: :unprocessable_entity
    end

    # Transcribe-only mode for clarification answers (quick transcription without full processing)
    if params[:transcribe_only].present? && params[:audio].present?
      begin
        audio = params[:audio]
        audio_data = Base64.strict_encode64(audio.read)

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15
        http.open_timeout = 5

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
        req.body = {
          contents: [ {
            parts: [
              { text: "Transcribe this short audio clip. Return ONLY the spoken text, nothing else. If unclear, return your best guess." },
              { inline_data: { mime_type: audio.content_type, data: audio_data } }
            ]
          } ]
        }.to_json

        res = http.request(req)
        body = JSON.parse(res.body) rescue {}

        parts = body.dig("candidates", 0, "content", "parts")
        raw = parts&.map { |p| p["text"] }&.join(" ")&.strip

        return render json: { raw_summary: raw || "" }
      rescue => e
        return render json: { error: e.message }, status: 500
      end
    end

    begin
      instruction = <<~PROMPT
        You are a STRICT data extractor for casual contractors (plumbers, electricians, techs).
Your job: convert spoken notes or written text into a single valid JSON invoice object. Be robust to slang and casual phrasing, but never invent financial values or change accounting semantics.

----------------------------
CORE DIRECTIVES (non-negotiable)
----------------------------
1. DO NOT invent data. Only extract facts explicitly stated. Use null for unknown or ambiguous fields instead of erroring, unless the entire input is unrelated to billing or a job. (EXCEPTION: For "clarifications" array, you MAY guess a reasonable placeholder value.)
2. DO NOT calculate totals. Return raw values (hours, rates, item prices). No multiplication or derived totals.
3. If user states a specific rate/price it overrides defaults. Provided values ALWAYS take priority.
4. Respect strict accounting rule: ANY reduction spoken/written as occurring "after tax", "off the total", "from the final bill", "at the end", "off the invoice" must be treated as a CREDIT (credit_flat), NOT a discount (global or otherwise). Item prices and taxes must remain unchanged in this case.
5. TAXABILITY: Return `taxable: null` (literal null) for all items unless the user EXPLICITLY says "tax free", "no tax", "exempt", or "add tax". Do NOT infer taxability yourself; allow the system default (based on tax scope) to apply.
6. GROUPS & BUNDLING: If a total price is given for a category (e.g. "Materials were 2300" or "Labor was 1200"), you MUST create ONE priced item for that category.
   - Example Input: "Condenser, coil, line set... materials were 2300"
   - Output: ONE Materials item { "name": "Materials", "qty": 1, "unit_price": 2300, "sub_categories": ["Condenser", "Coil", "Line set"], "taxable": null }.
   - LATE TOTAL RULE: Even if items are listed first without prices (e.g. "Got a condenser and a coil... total materials 2300"), consolidate them into a single item with the total price. Do NOT leave them priced at 0.
7. NUMERIC WORDS: "twelve hundred" -> 1200, "twenty-three hundred" -> 2300, "thirty-five hundred" -> 3500. Always return numbers as numeric strings or integers.
8. CLIENT EXTRACTION: Explicitly look for introductions like "This is [Name]", "Invoice for [Name]", "Bill to [Name]".
   - "Hello, this is Apex Roofing" -> Client: "Apex Roofing"
9. Output STRICT JSON. No extra fields. Use null for unknown numeric values, empty arrays for absent categories.

----------------------------
ERROR HANDLING (return **only** below JSON on error)
----------------------------
If input is complete gibberish or entirely unrelated to a contractor job ->
{"error":"Input unclear - please try again"}

If a numeric reduction is ambiguous (no currency or percent indicated) ->
DEFAULT TO CURRENCY (flat amount). Do not error.

If input empty or silent ->
{"error":"Input empty"}

If only non-billing talk (no labor/materials/fees/expenses/credits) -> error above.

----------------------------
NATURAL LANGUAGE / SLANG RULESET (pragmatic)
----------------------------
- Accept trade slang: "bucks", "quid" → count as currency; "knock off", "hook him up" → credit/discount intent; "trip charge", "service call" → fee; common part names ("P-Trap", "SharkBite") → materials.
- MEASUREMENTS vs QUANTITY: "25 feet of pipe" → Qty: 1, Name/Desc: "25 feet of pipe". Do NOT extract '25' as quantity unless it refers to discrete units (e.g. "25 pipes").
- If explicit currency word omitted (e.g., "Take 20 off"), treat as CURRENCY (flat amount). Only infer percent if "percent" or "%" is explicitly used.
- AMBIGUOUS QUANTITY: If user implies a range or uncertainty (e.g. "3 or 4", "maybe 5 or 6"), ALWAYS extract the HIGHER number.
- If user mentions a rate earlier (e.g., “$90 an hour”) assume it persists for subsequent hourly items until explicitly changed.
- If user says "usual rate", "standard rate", or "same rate", leave rate fields as NULL (system will apply defaults).
- DAY REFERENCES: When user mentions "day", "half day", "workday", or "X days" for labor time, convert using #{@profile.hours_per_workday || 8} hours per day. Examples: "three days" = #{(@profile.hours_per_workday || 8) * 3} hours, "half day" = #{(@profile.hours_per_workday || 8) / 2.0} hours.

----------------------------
CATEGORY RULES (must map correctly)
----------------------------
Categories: LABOR/SERVICE, MATERIALS, EXPENSES, FEES, CREDITS.

LABOR:
- If multiple distinct services are mentioned, create separate labor entries.
- If user gives "2 hours, $100 total": treat as fixed $100 (flat). Do NOT infer $50/hr.
- Hours + rate → mode "hourly", include hours and rate fields. Flat total → mode "fixed", include price field and set hours=1 or include hours as metadata (per your schema).
- If user sets multiplier like "time and a half" or "double rate", compute the new rate from the default hourly rate only when no explicit hourly was spoken. If explicit hourly rate spoken — use it.
- Do not propagate explicit rates to other hours. Only apply explicit rates to the hour they are spoken. For any other hour, use the default rate if unspecified.
- USE SPECIFIC TITLES for the 'desc' field (e.g., "AC Repair", "Emergency Call Out"). ALWAYS use Title Case.
- Be concise but descriptive.#{' '}
- Put additional task details into 'sub_categories' ONLY if they add new information.


MATERIALS:
- Physical goods the client keeps. Only extract the name of the item.
- BUNDLING: If user gives a TOTAL PRICE for "materials" (plural), create ONE item named "Materials" (or specific group name) with that price. List the specific items in 'sub_categories'.
- Extract QUANTITY into the 'qty' field (default 1).
- Extract UNIT PRICE (price per item) into 'unit_price'.
- DO NOT put "(x2)" or quantity info in the description/name if you are setting the 'qty' field.
- If user says "2 items at 40 each", 'qty' is 2 and 'unit_price' is 40.
- If quantity is "3 or 4", "3 to 4", use the HIGHER value (4) for the 'qty' field.
- Never include internal cost unless explicitly spoken (avoid exposing cost).

AMBIGUOUS ITEMS (Labor vs Materials):
- "Action + Object + Price" (e.g. "Replaced filter $25", "Cleaned vents $15") -> CLASSIFY AS LABOR/SERVICE. Name it "Filter Replacement" or "Vent Cleaning".
- REDUNDANCY CHECK: Do NOT add a sub_category that just repeats the main title or is a variation of it. (e.g. if desc is "AC Repair", do NOT add "Repaired AC" as a subcategory). Subcategories are ONLY for additional details (e.g. specific part names, location) not implied by the title.
- Only classify as Materials if the spoken text purely describes the object (e.g. "The filter cost $25", "New filter: $25").
- If in doubt, prefer Labor/Service for tasks.

EXPENSES:
- Pass-through reimbursables (parking, tolls, Uber). Usually not taxed. Price numeric required.
- BUNDLING: If user gives a TOTAL PRICE for "expenses" (plural), create ONE main item named "Expenses" (or specific group name) with that price. List component details in 'sub_categories'.

FEES:
- Surcharges, disposal, rush fees. Return `taxable: null` to defer to system settings unless user explicitly says "tax this" or "no tax".
- BUNDLING: Same logic as Materials/Expenses. If a total fee amount is given for multiple fee types, bundle them into one main Fee item with sub-categories.

CREDITS:
- Each credit reason must be its own entry with its own amount.
- If user describes multiple reasons with separate amounts, return multiple credit entries.
- If user describes a single amount with multiple reasons (or no reason), use "Courtesy Credit" as the default reason. Do NOT return multiple credits for the same amount.
- Example: "Add a credit for 50" -> { "amount": 50, "reason": "Courtesy Credit" }.

----------------------------
DISCOUNT vs CREDIT RULES (explicit)
----------------------------
- Default: discounts = PRE-TAX. They reduce taxable base and must be applied proportionally or scoped per-category as instructed.
- If user says "after tax", "off the total", "from the final amount" → treat as CREDIT (post-tax) and do NOT change item taxable flags or prices.
- Ambiguous "take $X off" with no timing language → default to GLOBAL DISCOUNT (pre-tax).
- EXCLUSION LOGIC: If input says "discount everything except [category]", you are STRICTLY FORBIDDEN from using "global_discount". You MUST apply the discount to every other item individually (labor, materials, fees) and leave the excluded category 0.

----------------------------
EXTRACTION STRATEGY (MULTI-PASS)
----------------------------
- STEP 1: Scan the ENTIRE text for currency totals (e.g., "$2300", "twelve hundred").#{' '}
- STEP 2: Map these totals to their functional categories (Labor, Materials, Fees).
- STEP 3: ONLY then gather descriptions and sub-categories.
- LATE TOTAL RULE: If items are listed first (e.g. "Condenser, coil, pipe...") and a price follows later (e.g. "...materials were 2300"), you MUST consolidate them. It is strictly forbidden to leave the categorized parts with $0. Create ONE priced item and use the parts as sub-categories.

----------------------------
TAXABILITY & PRICES (STRICT)
----------------------------
1. TAXABLE FIELD:#{' '}
   - DEFAULT: Return `taxable: null` to use system defaults.
   - EXPLICIT "Tax everything except [X]": Set `taxable: false` for X items, and `taxable: true` for ALL other items.
   - EXPLICIT "Tax [X] only": Set `taxable: true` for X items, `taxable: false` for others.
   - EXPLICIT "Tax materials" or "Tax parts": Set `taxable: true` for Materials.
2. PRICE BUNDLING: Always consolidate. "Labor was 1200" -> ONE fixed labor item, price 1200. "Materials 2300" -> ONE materials item, qty 1, unit_price 2300.
3. NUMERIC WORDS: "twelve hundred" -> 1200, "twenty-three hundred" -> 2300.

----------------------------
TAX SCOPE & RATES
----------------------------
- DEFAULT SCOPE: Use null if no instruction.#{' '}
- EXPLICIT SCOPE: If user says "tax ONLY on parts", `tax_scope` MUST be "materials".
- TAX RATES: "8% tax" -> tax_rate: 8.0.

----------------------------
CLARIFICATION QUESTIONS (CRITICAL - ask the user to confirm uncertain or missing values)
----------------------------
You MUST ask clarification questions in these cases:

1. MISSING VALUES - When a category is mentioned but NO price/amount is given:
   - "parts were expensive" -> guess 0 or a placeholder, ask "What was the cost for parts?"
   - "materials cost a lot" -> ask "What was the total for materials?"
   - "charged for labor" -> ask "What was the labor charge?"

2. AMBIGUOUS/APPROXIMATE VALUES - When the value is unclear:
   - "just under 800" -> guess 795, ask "You said 'just under 800'. What's the exact amount?"
   - "around 500" -> guess 500, ask "You said 'around 500'. Is $500 correct?"
   - "about 2 hours" -> guess 2, ask "You said 'about 2 hours'. Is 2 hours the exact time?"
   - "eh, call it five hours" -> guess 5, ask "You said 'call it 5 hours'. Is 5 hours final?"
   - "a few items" -> guess 3, ask "How many items exactly?"

3. VAGUE DESCRIPTORS instead of numbers:
   - "expensive", "a lot", "significant amount", "good chunk" -> ALWAYS ask for the actual value
   - "some hours", "took a while" -> ALWAYS ask for the exact time

FORMAT: { "field": "[category].[field_name]", "guess": [your_best_guess_or_0], "question": "[short direct question]" }

RULES:
- Limit to 5 clarifications maximum per request (prioritize most impactful ones)
- Do NOT ask if the value is clear and explicit (e.g., "800 dollars" needs no clarification)
- Do NOT ask about ANY RATES (hourly rate, team rate, special rate, tax rate) - the system has user-configured defaults
- ONLY ask about missing PRICES or COSTS (e.g., "parts were expensive" but no dollar amount given)
- CRITICAL: When you add a clarification with a guess value, you MUST populate the corresponding JSON field with that SAME value. The guess and actual field value must match.

----------------------------
DISAMBIGUATION RULES
----------------------------
- If a numeric reduction has no currency or percent -> Default to CURRENCY.
- If hours are spoken with no rate and no default exists -> return hours with hourly_rate = null (system will apply default).

----------------------------
OUTPUT & TONE
----------------------------
- Professional Tone & Formatting: Use Title Case for the 'desc' field (e.g. "AC Repair", not "Ac repair").
- **Brevity Extreme**: Choose primary descriptions ('desc'/'name') and subcategory names to be as short as possible without sacrificing informativeness. Use concise, impactful technical terms.
- Keep descriptions short and free of parentheses/metadata.
- Put all specific actions/details into the 'sub_categories' array.

----------------------------
OUTPUT JSON SCHEMA (must match exactly)
----------------------------
Return EXACTLY the JSON structure below (use null for unknown numeric, empty arrays for absent categories):

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
  "credits": [
    { "amount": "", "reason": "" }
  ],
  "currency": "ISO 4217 code (e.g., USD, GBP, EUR)",#{' '}
  "billing_mode": null,
  "tax_scope": "",
  "labor_service_items": [
    { "desc": "", "hours": "", "rate": "", "price": "", "mode": "hourly|fixed", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "materials": [
    { "name": "", "qty": "", "unit_price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "expenses": [
    { "name": "", "price": "", "taxable": false, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "fees": [
    { "name": "", "price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "due_days": null,
  "due_date": null,
  "raw_summary": "",
  "clarifications": [
    { "field": "materials.unit_price", "guess": 795, "question": "You said 'just under 800' for parts. What's the exact amount?" }
  ]
}
PROMPT

      if is_manual_text
        prompt_parts = [
          { text: instruction },
          { text: "USER INPUT (MANUAL TEXT):\n#{params[:manual_text]}" }
        ]
      else
        audio = params[:audio]
        return render json: { error: "No audio" }, status: 400 unless audio

        if audio.size > 10.megabytes
          return render json: { error: "Audio too large (Limit: 10MB)" }, status: 413
        end

        audio_data = Base64.strict_encode64(audio.read)
        prompt_parts = [
          { text: instruction },
          { inline_data: { mime_type: audio.content_type, data: audio_data } }
        ]
      end

      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
      req.body = { contents: [ { parts: prompt_parts } ] }.to_json

      res = http.request(req)
      body = JSON.parse(res.body) rescue {}

      parts = body.dig("candidates", 0, "content", "parts")
      raw = parts&.map { |p| p["text"] }&.join("\n")

      unless raw
        Rails.logger.error "AI FAILURE: No raw text in response. Body: #{body.to_json}"
        return render json: { error: "AI failed to generate a response" }, status: 500
      end

      Rails.logger.info "AI RAW RESPONSE: #{raw}"

      # More robust JSON extraction to handle preamble or "thinking" blocks
      json_match = raw.match(/\{[\s\S]*\}/m)
      json = nil
      if json_match
        begin
          json = JSON.parse(json_match[0])
        rescue => e
          Rails.logger.error "AI JSON PARSE ERROR: #{e.message}. Raw: #{raw}"
        end
      else
        Rails.logger.error "AI NO JSON FOUND IN RAW: #{raw}"
      end

      return render json: { error: "Invalid AI output" }, status: 422 unless json

      if json["error"]
        Rails.logger.warn "AI RETURNED ERROR: #{json["error"]}"
        return render json: { error: json["error"] }, status: 422
      end

      Rails.logger.info "AI_PROCESSED: #{json}"

      # Enforce Array Safety
      %w[labor_service_items materials expenses fees credits].each { |k| json[k] = Array(json[k]) }

      # ---------- NORMALIZATION ----------

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

      # Pass Credit - REMOVE legacy single fields
      # json["credit_flat"] -> REMOVED
      # json["credit_reason"] -> REMOVED

      # Normalize Credits Array
      json["credits"] ||= []

      # Strict post-tax credit enforcement
      # If detecting "post_tax" mode, ensure we aren't applying discounts incorrectly,
      # but technically the prompt handles this by putting them in credits[].

      # Filter and Normalize Credits
      json["credits"] = json["credits"].map do |c|
        {
          "amount" => clean_num(c["amount"]),
          "reason" => c["reason"].to_s.strip.presence || "Courtesy Credit"
        }
      end.select { |c| c["amount"].present? && c["amount"] > 0 }

      # Pass Discount Tax Mode (pre_tax only, otherwise nil for profile default)
      # Post-tax discounts are PROHIBITED (must be credits).
      json["discount_tax_mode"] = json["discount_tax_mode"] == "pre_tax" ? "pre_tax" : nil


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

        # LABOR/SERVICE items (no price - tied to labor charge)
        # Unified Logic: Populate from top-level if array is empty
        if json["labor_service_items"].blank? && (json["labor_hours"].present? || json["fixed_price"].present?)
          # item_price removed (was unused)
          json["labor_service_items"] = [ {
            "desc" => "Work performed",
            "hours" => json["labor_hours"],
            "price" => json["fixed_price"],
            "mode" => json["billing_mode"] || "hourly",
            "rate" => json["hourly_rate"],
            "sub_categories" => []
          } ]
        end

      if json["labor_service_items"]&.any?
        # Safety: Promotion of spoken rate to Master Rate
        # Scan ALL items for the first mentions of a rate if global is missing
        if json["hourly_rate"].blank?
          first_rate_item = json["labor_service_items"].find { |i| i.is_a?(Hash) && i["rate"].present? }
          json["hourly_rate"] = clean_num(first_rate_item["rate"]) if first_rate_item
        end

        json["sections"] << {
          title: "Labor/Service",
          items: json["labor_service_items"].each_with_index.map do |item, idx|
            if item.is_a?(Hash)
              # Priority: If mode is fixed, use price. If hourly, use hours.
              item_mode = item["mode"].presence || json["billing_mode"] || "hourly"

              # Improved value mapping logic
              raw_hours = clean_num(item["hours"])
              raw_price = clean_num(item["price"])
              raw_rate  = clean_num(item["rate"])

              item_qty_or_amount, item_rate_val = if item_mode == "fixed"
                 # In fixed mode, we favor price, then rate, then hours.
                 [ raw_price.presence || raw_rate.presence || raw_hours.presence, @profile.hourly_rate ]
              else
                 # In hourly mode, we favor hours.
                 # If no hours but we have a price, that price should reflect the RATE, not the HOURS.
                 target_qty = raw_hours.presence || "1"
                 target_rate = if raw_hours.present?
                                 raw_rate.presence || raw_price.presence
                 else
                                 raw_price.presence || raw_rate.presence
                 end
                 [ target_qty, target_rate.presence || @profile.hourly_rate ]
              end

              if item_qty_or_amount.blank? && idx == 0
                item_qty_or_amount = (json["billing_mode"] == "fixed" ? clean_num(json["fixed_price"]) : clean_num(json["labor_hours"]))
              end

              # Safety: Only inherit top-level labor FLAt discount if there is exactly ONE labor item.
              # Percentage discounts can apply to all items (mathematically equivalent).
              inherit_flat_discount = json["labor_service_items"].size == 1
              inherit_percent_discount = true

              {
                desc: item["desc"].to_s.strip,
                price: item_qty_or_amount,
                rate: item_rate_val,
                mode: item_mode,
                # Fix: Default to true if nil, so that UI can decide based on scope.
                # Actually, better to determine it here based on scope if nil.
                taxable: item["taxable"].nil? ? (effective_tax_scope.include?("labor") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total")) : to_bool(item["taxable"]),
                tax_rate: clean_num(item["tax_rate"]),
                discount_flat: clean_num(item["discount_flat"].presence || (inherit_flat_discount && json["labor_discount_flat"].present? && item["discount_flat"].blank? ? json["labor_discount_flat"] : "")),
                discount_percent: clean_num(item["discount_percent"].presence || (inherit_percent_discount && json["labor_discount_percent"].present? && item["discount_percent"].blank? ? json["labor_discount_percent"] : "")),
                sub_categories: Array(item["sub_categories"])
              }
            else
              {
                desc: item.to_s.strip,
                price: (idx == 0 ? (json["billing_mode"] == "fixed" ? json["fixed_price"] : json["labor_hours"]) : ""),
                discount_flat: clean_num(json["labor_discount_flat"].present? ? json["labor_discount_flat"] : ""),
                discount_percent: clean_num(json["labor_discount_percent"].present? ? json["labor_discount_percent"] : ""),
                sub_categories: []
              }
            end
          end
        }
      end

      # MATERIALS (physical goods with price)
      if json["materials"]&.any?
        json["sections"] << {
          title: "Materials",
          items: json["materials"].map do |m|
            # Fallback: Extract quantity from description if missing in field
            d_text = (m["name"].presence || m["desc"].presence || "").to_s.strip
            q_val = clean_num(m["qty"])

            if q_val.nil? || q_val == 1.0
              # Try to find (x5), x5, (5), 5 off
              if match = d_text.match(/[\(\s]x?(\d+)[\)]?$/i) || d_text.match(/^(\d+)\s+x\s+/)
                 extracted_q = match[1].to_f
                 if extracted_q > 1
                   q_val = extracted_q
                   # key: remove (x2) from description? Maybe keeps it clean.
                   d_text = d_text.gsub(/[\(\s]x?(\d+)[\)]?$/i, "").strip.sub(/^(\d+)\s+x\s+/, "")
                 end
              elsif match = d_text.match(/^(\d+)\s+([A-Za-z]+)/) # "2 Fittings", but careful with "2 inch"
                  dist = match[1].to_f
                  # Simple heuristic: if quantity is 1 (default), and desc starts with "2 Fittings", assume 2 is qty
                  # BUT exclude common measurements like "2 inch", "3 mm"
                  word = match[2].downcase
                  unless %w[inch in mm cm m ft kg lb oz gal].include?(word)
                    if dist > 1
                       q_val = dist
                       d_text = d_text.sub(/^(\d+)\s+/, "")
                    end
                  end
              elsif match = d_text.match(/\s(\d+)\s+each$/i)
                  extracted_q = match[1].to_f
                  if extracted_q > 1
                    q_val = extracted_q
                    d_text = d_text.gsub(/\s(\d+)\s+each$/i, "").strip
                  end
              end
            end

            {
              desc: d_text,
              qty: q_val || 1,
              price: clean_num(m["unit_price"]),
              taxable: to_bool(m["taxable"]),
              tax_rate: clean_num(m["tax_rate"]),
              discount_flat: clean_num(m["discount_flat"]),
              discount_percent: clean_num(m["discount_percent"]),
              sub_categories: Array(m["sub_categories"])
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
              desc: (e["name"].presence || e["desc"].presence || "").to_s.strip,
              price: clean_num(e["price"]),
              taxable: to_bool(e["taxable"]), # Default handled in helper if nil logic needed, but strict bool here
              tax_rate: clean_num(e["tax_rate"]),
              discount_flat: clean_num(e["discount_flat"]),
              discount_percent: clean_num(e["discount_percent"]),
              sub_categories: Array(e["sub_categories"])
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
              desc: (f["name"].presence || f["desc"].presence || "").to_s.strip,
              price: clean_num(f["price"]),
              taxable: to_bool(f["taxable"]), # Default handled in helper if nil logic needed, but strict bool here
              tax_rate: clean_num(f["tax_rate"]),
              discount_flat: clean_num(f["discount_flat"]),
              discount_percent: clean_num(f["discount_percent"]),
              sub_categories: Array(f["sub_categories"])
            }
          end
        }
      end

      final_response = {
        "client" => json["client"],
        "time" => json["time"],
        "raw_summary" => (is_manual_text ? nil : json["raw_summary"]),
        "sections" => json["sections"],
        "tax_scope" => json["tax_scope"],
        "billing_mode" => json["billing_mode"],
        "currency" => json["currency"],
        "hourly_rate" => json["hourly_rate"],
        "labor_tax_rate" => json["labor_tax_rate"],
        "labor_taxable" => json["labor_taxable"],
        "labor_discount_flat" => json["labor_discount_flat"],
        "labor_discount_percent" => json["labor_discount_percent"],
        "global_discount_flat" => json["global_discount_flat"],
        "global_discount_percent" => json["global_discount_percent"],
        "credits" => json["credits"], # Now the only source of truth
        "discount_tax_mode" => json["discount_tax_mode"],
        "due_days" => json["due_days"],
        "due_date" => json["due_date"],
        "clarifications" => Array(json["clarifications"]).select { |c| c.is_a?(Hash) && c["question"].present? }
      }

      Rails.logger.info "FINAL NORMALIZED JSON: #{final_response.to_json}"

      render json: final_response

    rescue => e
      render json: { error: e.message }, status: 500
    end
  end


  def clean_num(val)
    return nil if val.blank?

    # Extract digits, decimal points, and negative signs
    # We strip expensive word-to-number logic since the AI prompt ensures numeric JSON output
    stripped = val.to_s.gsub(/[^0-9.-]/, "")
    return nil if stripped.blank?

    f = stripped.to_f
    (f % 1 == 0) ? f.to_i : f
  end

  def to_bool(val)
    return false if val.nil?
    str = val.to_s.downcase.strip
    [ "true", "1", "yes", "on" ].include?(str)
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
      :hours_per_workday,
      :tax_rate,
      :tax_scope,
      :payment_instructions,
      :billing_mode,
      :currency,
      :invoice_style,
      :discount_tax_rule,
      :remove_logo,
      :logo,
      :accent_color
    )
  end
end
