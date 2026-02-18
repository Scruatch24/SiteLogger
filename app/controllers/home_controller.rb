class HomeController < ApplicationController
  helper :logs
  require "net/http"
  require "uri"
  require "json"
  require "base64"
  require "digest"
  require "cgi"



  def complete_onboarding
    if user_signed_in? && @profile.persisted?
      @profile.update_columns(onboarded: true)
    end
    head :ok
  end

  def sitemap
    headers["Content-Type"] = "application/xml"
    render xml: <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url>
          <loc>https://talkinvoice.online/</loc>
          <changefreq>weekly</changefreq>
          <priority>1.0</priority>
        </url>
        <url>
          <loc>https://talkinvoice.online/users/sign_in</loc>
          <changefreq>monthly</changefreq>
          <priority>0.5</priority>
        </url>
        <url>
          <loc>https://talkinvoice.online/users/sign_up</loc>
          <changefreq>monthly</changefreq>
          <priority>0.6</priority>
        </url>
      </urlset>
    XML
  end

  def pricing
  end

  def subscription
    unless user_signed_in? && current_user.profile&.ever_paid?
      redirect_to pricing_path and return
    end

    load_subscription_billing_data(current_user.profile)
  end

  def create_billing_portal
    profile = current_user&.profile

    unless user_signed_in? && profile&.ever_paid?
      redirect_to pricing_path and return
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    if api_key.blank?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable") and return
    end

    customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
    resolved_customer_id = customer_id

    if customer_id.blank?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_customer_missing") and return
    end

    portal_result = paddle_customer_portal_url(api_key: api_key, customer_id: resolved_customer_id)
    if portal_result == :customer_missing
      if profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.present?
        profile.update_columns(paddle_customer_id: nil)
      end

      refreshed_customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
      if refreshed_customer_id.present?
        resolved_customer_id = refreshed_customer_id
        portal_result = paddle_customer_portal_url(api_key: api_key, customer_id: resolved_customer_id)
      end
    end

    if portal_result == :forbidden
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_permissions") and return
    end

    unless portal_result.is_a?(String) && portal_result.present?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable") and return
    end

    if profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.blank? && resolved_customer_id.present?
      profile.update_columns(paddle_customer_id: resolved_customer_id)
    end

    redirect_to portal_result, allow_other_host: true
  rescue => e
    Rails.logger.warn("PADDLE BILLING PORTAL ERROR: #{e.message}")
    redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable")
  end

  def contact
  end

  def send_contact
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    description = params[:description].to_s.strip

    if email.blank? || subject.blank? || description.blank?
      flash[:alert] = t("contact_page.validation_error")
      redirect_to contact_path and return
    end

    begin
      ContactMailer.notify_admin(email: email, subject: subject, description: description).deliver_later
      ContactMailer.confirm_user(email: email, locale: I18n.locale).deliver_later
      flash[:notice] = t("contact_page.success")
    rescue => e
      Rails.logger.error("Contact form error: #{e.message}")
      flash[:notice] = t("contact_page.success")
    end

    redirect_to contact_path
  end

  def terms
  end

  def privacy
  end

  def refund
  end

  def checkout
  end

  def confirm_checkout
    unless user_signed_in?
      return render json: { success: false, error: "unauthorized" }, status: :unauthorized
    end

    transaction_id = params[:transaction_id].to_s.strip
    if transaction_id.blank?
      return render json: { success: false, error: "missing_transaction_id" }, status: :unprocessable_entity
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    if api_key.blank?
      return render json: { success: false, error: "paddle_api_key_missing" }, status: :unprocessable_entity
    end

    transaction = paddle_transaction_details(api_key: api_key, transaction_id: transaction_id)
    if transaction == :forbidden
      Rails.logger.warn("PADDLE CHECKOUT CONFIRM: Paddle API unauthorized. Check PADDLE_API_KEY permissions/environment.")
      return render json: { success: false, error: "paddle_api_unauthorized", retryable: false }, status: :unprocessable_entity
    end

    if transaction.blank?
      Rails.logger.info("PADDLE CHECKOUT CONFIRM: transaction not found yet (transaction_id=#{transaction_id})")
      return render json: { success: false, error: "transaction_not_found", retryable: true }, status: :accepted
    end

    status = transaction["status"].to_s.downcase
    unless [ "paid", "completed", "billed" ].include?(status)
      retryable = [ "ready", "draft", "pending", "processing" ].include?(status)
      Rails.logger.info("PADDLE CHECKOUT CONFIRM: not paid yet (transaction_id=#{transaction_id}, status=#{status}, retryable=#{retryable})")
      return render json: { success: false, error: "transaction_not_paid", status: status, retryable: retryable }, status: (retryable ? :accepted : :unprocessable_entity)
    end

    customer_id = transaction["customer_id"].presence || transaction.dig("customer", "id")
    customer_email = transaction.dig("customer", "email").presence ||
      transaction["customer_email"].presence
    custom_data_user_id = transaction.dig("custom_data", "user_id").to_s
    subscription_id = transaction["subscription_id"]
    item = (transaction["items"] || []).first || {}
    price_id = item["price_id"].presence || item.dig("price", "id")

    profile = current_user.profile
    owned_by_current_user =
      custom_data_user_id == current_user.id.to_s ||
      customer_email.to_s.casecmp(current_user.email.to_s).zero? ||
      (profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.to_s == customer_id.to_s)

    unless owned_by_current_user
      Rails.logger.warn("PADDLE CHECKOUT CONFIRM: user mismatch (transaction_id=#{transaction_id}, user_id=#{current_user.id})")
      return render json: { success: false, error: "transaction_user_mismatch" }, status: :forbidden
    end

    update_attrs = {
      plan: "paid",
      paddle_price_id: price_id,
      paddle_customer_email: (customer_email.presence || current_user.email),
      paddle_subscription_status: "active"
    }
    if profile.respond_to?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end
    update_attrs[:paddle_subscription_id] = subscription_id if subscription_id.present?

    profile.update_columns(update_attrs)
    Rails.logger.info("PADDLE CHECKOUT CONFIRM: upgraded profile_id=#{profile.id} transaction_id=#{transaction_id}")
    render json: { success: true }
  rescue => e
    Rails.logger.warn("PADDLE CHECKOUT CONFIRM ERROR: #{e.message}")
    render json: { success: false, error: "checkout_confirm_failed" }, status: :unprocessable_entity
  end

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
      current_user.logs.kept.eager_load(:categories).order("logs.pinned DESC NULLS LAST, logs.pinned_at ASC NULLS LAST, logs.invoice_number DESC NULLS LAST")
    else
      # Guest history is private to the IP adress - return empty as requested
      []
    end

    @categories = if user_signed_in?
      # Ensure Favorites category exists and has correct styling (Self-Healing)
      fav = current_user.categories.where("name ILIKE ?", "Favorites").first_or_initialize
      if fav.new_record? || fav.name != "Favorites" || fav.color != "#EAB308" || fav.icon != "star"
        fav.update(name: "Favorites", color: "#EAB308", icon: "star", icon_type: "premade")
      end

      current_user.categories.preload(:log_category_assignments, logs: :log_category_assignments).order(name: :asc)
    else
      []
    end
  end

  def settings
    # @profile is already set by the before_action
    # Guests can view but fields are disabled in the view
  end

  def profile
    @is_new_profile = !@profile.persisted?
    # Guests can view but fields are disabled in the view
  end

  def save_profile
    if @profile.guest?
      return render json: { success: false, errors: [ t('guests_cannot_save') ] }, status: :forbidden
    end

    # Strip logo from params if free user tries to upload
    filtered = profile_params
    unless @profile.paid?
      filtered = filtered.except(:logo)
    end

    @profile.assign_attributes(filtered)

    respond_to do |format|
      if @profile.save
        format.html { redirect_to profile_path, notice: t("profile_saved") }
        format.json { render json: { success: true, message: t("profile_saved") } }
      else
        format.html { render :profile, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def set_session_locale
    locale = params[:locale].to_s
    if I18n.available_locales.map(&:to_s).include?(locale)
      session[:system_language] = locale
      session[:locale_explicitly_set] = true

      if user_signed_in? && @profile.persisted?
        @profile.update_columns(system_language: locale)
      end
    end

    head :ok
  end

  def set_transcript_language
    lang = params[:language].to_s
    if %w[en ge ka].include?(lang)
      db_lang = (lang == "ge") ? "ka" : lang
      session[:transcription_language] = db_lang

      if user_signed_in? && @profile.persisted?
        @profile.update_columns(transcription_language: db_lang)
      end
    end

    head :ok
  end

  def enhance_transcript_text
    api_key = ENV["GEMINI_API_KEY"]
    limit = @profile.char_limit
    enhancement_limit = @profile.enhancement_limit
    raw_text = params[:manual_text].to_s.strip

    if raw_text.blank?
      return render json: { error: t("input_empty", default: "Input empty") }, status: :unprocessable_entity
    end

    if raw_text.length > limit
      return render json: { error: "#{t('transcript_limit_exceeded')} (#{limit})." }, status: :unprocessable_entity
    end

    if enhancement_limit.present?
      usage_scope = UsageEvent.where(event_type: "text_enhancement")
                              .where("created_at >= ?", Time.current.beginning_of_day)

      usage_scope = if user_signed_in?
        usage_scope.where(user_id: current_user.id)
      else
        usage_scope.where(user_id: nil, ip_address: client_ip)
      end

      if usage_scope.count >= enhancement_limit
        return render json: {
          error: t("daily_limit_reached", limit: enhancement_limit)
        }, status: :too_many_requests
      end
    end

    doc_language = (params[:language] || @profile.try(:transcription_language) || session[:transcription_language] || @profile.try(:document_language) || "en").to_s.downcase
    target_language_name = case doc_language
    when "ge", "ka"
      "Georgian"
    when "en"
      "English"
    else
      "the language identified by ISO code '#{doc_language}'"
    end
    output_language_rule = "Return output only in #{target_language_name}."

    instruction = <<~TEXT
      You rewrite transcript text so downstream invoice extraction is more reliable.
      This output will be consumed by a separate strict JSON invoice extraction AI model.
      Rewrite for machine-readability: clear sentence boundaries, explicit wording, and minimal ambiguity.
      Keep all facts unchanged: names, quantities, prices, dates, and technical details.
      Keep all numbers/currency values exact as provided.
      Improve grammar, punctuation, and clarity. Remove filler words/repetitions.
      Do NOT add any new information.
      If USER TEXT is not already in #{target_language_name}, first translate it to #{target_language_name}, then enhance it.
      If USER TEXT is already in #{target_language_name}, do not translate.
      #{output_language_rule}
      Output MUST be at most #{limit} characters.
      Return ONLY the rewritten text. No JSON, no markdown, no quotes.

      USER TEXT:
      #{raw_text}
    TEXT

    primary_model = ENV["GEMINI_PRIMARY_MODEL"].presence || "gemini-2.5-flash-lite"
    fallback_model = ENV["GEMINI_FALLBACK_MODEL"].presence || "gemini-2.5-flash"
    model_chain = [ primary_model, fallback_model ].map { |m| m.to_s.strip }.reject(&:blank?).uniq.take(2)

    enhanced_text = nil

    model_chain.each do |gemini_model|
      body = gemini_generate_content(
        api_key: api_key,
        model: gemini_model,
        prompt_parts: [ { text: instruction } ],
        cached_instruction_name: nil
      )

      if body["error"].present?
        Rails.logger.warn("ENHANCE MODEL ERROR (#{gemini_model}): #{body["error"].to_json}")
        next
      end

      parts = body.dig("candidates", 0, "content", "parts")
      candidate = parts&.map { |p| p["text"] }&.join(" ")&.to_s&.strip
      next if candidate.blank?

      candidate = candidate.gsub(/\A```(?:text)?\s*/i, "").gsub(/\s*```\z/, "").strip
      candidate = candidate.gsub(/\A["“”']+|["“”']+\z/, "").strip
      next if candidate.blank?

      enhanced_text = candidate[0, limit]
      break
    end

    if enhanced_text.blank?
      return render json: { error: t("ai_failed_response") }, status: 500
    end

    # Conservative guardrail: reject only when a classifier is highly confident
    # the enhanced transcript is incoherent or unrelated to invoice extraction.
    begin
      validator_prompt = <<~TEXT
        You validate whether transcript text is usable for invoice JSON extraction.
        Return invoice_related=false ONLY when the text is clearly gibberish/incoherent
        OR clearly unrelated to invoicing/billing/work log/services/products/expenses.
        If uncertain, return true.

        Return STRICT JSON only:
        {"invoice_related": true/false, "confidence": 0.0-1.0}

        TEXT:
        #{enhanced_text}
      TEXT

      validation_model = model_chain.first || "gemini-2.5-flash-lite"
      validation_body = gemini_generate_content(
        api_key: api_key,
        model: validation_model,
        prompt_parts: [ { text: validator_prompt } ],
        cached_instruction_name: nil
      )

      validation_parts = validation_body.dig("candidates", 0, "content", "parts")
      validation_raw = validation_parts&.map { |p| p["text"] }&.join(" ")&.to_s&.strip

      if validation_raw.present?
        validation_json = validation_raw[/\{.*\}/m]
        if validation_json.present?
          parsed = JSON.parse(validation_json) rescue nil
          invoice_related = parsed.is_a?(Hash) ? parsed["invoice_related"] : nil
          confidence = parsed.is_a?(Hash) ? parsed["confidence"].to_f : 0.0

          if invoice_related == false && confidence >= 0.8
            return render json: { error: t("input_unclear") }, status: :unprocessable_entity
          end
        end
      end
    rescue => e
      Rails.logger.warn("ENHANCE VALIDATION SKIPPED: #{e.message}")
    end

    begin
      UsageEvent.create!(
        user_id: current_user&.id,
        ip_address: client_ip,
        session_id: session.id.to_s,
        event_type: "text_enhancement"
      )
    rescue => e
      Rails.logger.warn("ENHANCE USAGE LOGGING FAILED: #{e.message}")
    end

    render json: { enhanced_text: enhanced_text }
  rescue => e
    Rails.logger.error("ENHANCE TRANSCRIPT ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: t("processing_error") }, status: 500
  end

  def save_settings
    if @profile.guest?
      return render json: { success: false, errors: [ t('guests_cannot_save') ] }, status: :forbidden
    end

    # We use the @profile set by before_action
    @profile.assign_attributes(profile_params)

    # Force classic style and orange accent for free users
    unless @profile.paid?
      @profile.invoice_style = "classic"
      @profile.accent_color = "#F97316"
    end

    respond_to do |format|
      if @profile.save
        session[:locale_explicitly_set] = true
        format.html { redirect_to settings_path, notice: t("profile_saved") }
        format.json { render json: { success: true, message: t("profile_saved") } }
      else
        format.html { render :settings, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def process_audio
    api_key = ENV["GEMINI_API_KEY"]
    has_audio = params[:audio].present?
    is_manual_text = !has_audio && params[:manual_text].present?
    mode = @profile.billing_mode || "hourly"
    limit = @profile.char_limit

    # Server-side Audio Duration Check
    if has_audio && params[:audio_duration].present? && params[:audio_duration].to_f < 1.0
       return render json: { error: t("audio_too_short") }, status: :unprocessable_entity
    end

    # Character Limit Check
    current_length = params[:manual_text].to_s.length
    # We allow a 250-character buffer on the server to account for the overhead
    # of [User clarification...] tags added during refinements.
    # The frontend strictly enforces the raw user limit of #{limit}.
    if is_manual_text && current_length > (limit + 250)
      return render json: {
        error: "#{t('transcript_limit_exceeded')} (#{limit + 250})."
      }, status: :unprocessable_entity
    end

    # Transcribe-only mode for clarification answers (quick transcription without full processing)
    if params[:transcribe_only].present? && params[:audio].present?
      begin
        audio = params[:audio]
        audio_data = Base64.strict_encode64(audio.read)

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent")
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
        Rails.logger.error "TRANCRIPTION ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
        return render json: { error: t("transcription_failed") }, status: 500
      end
    end

    # Priority: 1. URL Param, 2. Profile Transcription Lang, 3. session, 4. Profile Doc Lang, 5. Default English
    # NOTE: AI language should not be affected by UI/system language
    doc_language = params[:language] || @profile.try(:transcription_language) || session[:transcription_language] || @profile.try(:document_language) || "en"
    target_is_georgian = (doc_language == "ge" || doc_language == "ka")

    lang_context = if target_is_georgian
      "TARGET LANGUAGE: Georgian. Translate ONLY the text content (item names, descriptions, sub_categories text) to Georgian. The JSON structure (field names, section categories like 'labor', 'materials') stays the same. Do NOT reorganize or bundle items differently due to translation. E.g., 'Nails' becomes 'ლურსმნები', 'Filter Replacement' becomes 'ფილტრის შეცვლა'."
    else
      "TARGET LANGUAGE: English. All extracted names, descriptions, and sub_categories text MUST be in English. If the input is in Georgian or any other language, you MUST translate ALL text content to English. Do NOT leave any Georgian text in item names or descriptions. E.g., 'ნაჯახი' becomes 'Axe', 'მაცივრის შეკეთება' becomes 'Refrigerator Repair', 'ფანჯრის შეკეთება' becomes 'Window Repair', 'ლურსმანი' becomes 'Nail'."
    end

    # Section Labels for the generated JSON
    # IMPORTANT: Section titles should match the SYSTEM LANGUAGE (UI), NOT the Transcript Language
    # The Transcript Language only affects item names/descriptions, not category titles
    ui_is_georgian = (I18n.locale.to_s == "ka")
    sec_labels = if ui_is_georgian
      { labor: "პროფესიონალური მომსახურება", materials: "მასალები/პროდუქტები", expenses: "ხარჯები", fees: "მოსაკრებლები", notes: "შენიშვნები" }
    else
      { labor: "Labor/Service", materials: "Materials/Products", expenses: "Expenses", fees: "Fees", notes: "Field Notes" }
    end

    hours_per_workday = (@profile.hours_per_workday.presence || 8).to_f
    hours_per_workday = hours_per_workday.to_i if (hours_per_workday % 1).zero?
    three_days_hours = hours_per_workday * 3
    half_day_hours = hours_per_workday / 2.0
    today_for_prompt = Date.today.strftime("%b %d, %Y")

    begin
      instruction = <<~PROMPT
        #{lang_context}
        You are a STRICT data extractor for casual contractors (plumbers, electricians, techs).
Your job: convert spoken notes or written text into a single valid JSON invoice object. Be robust to slang and casual phrasing, but never invent financial values or change accounting semantics.

AUDIO RECONCILIATION RULE:
- If both audio and a "BROWSER LIVE TRANSCRIPT" text block are provided, use the AUDIO as the primary source of truth and treat browser text as a noisy hint.
- Reconcile phrase-by-phrase and keep whichever wording is more accurate from either source.
- The "raw_summary" field MUST contain the final reconciled transcript text.

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
{"error":"#{t('input_unclear', default: 'Input unclear - please try again')}"}

If a numeric reduction is ambiguous (no currency or percent indicated) ->
DEFAULT TO CURRENCY (flat amount). Do not error.

If input empty or silent ->
{"error":"#{t('input_empty', default: 'Input empty')}"}

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
- DAY REFERENCES: When user mentions "day", "half day", "workday", or "X days" for labor time, convert using #{hours_per_workday} hours per day. Examples: "three days" = #{three_days_hours} hours, "half day" = #{half_day_hours} hours.
- DATE EXTRACTION: If user mentions WHEN the work was done (e.g., "yesterday", "last Tuesday", "on February 5th", "this was from last week", "the job was on Monday", "set the date to...", "change the date to..."), extract this as the invoice date and return it in the "date" field. Use format "MMM DD, YYYY" (e.g., "Feb 07, 2026"). Today's date is #{today_for_prompt}. If no date is mentioned, return null for the "date" field.

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
- FREE LABOR ITEMS: If user mentions "free", "no charge", "complimentary", "on the house" (Georgian: "უფასოდ", "უფასო", "უფასოდ ჩავუთვლი", "უფასოდ გავუკეთე") for a labor item, you MUST set price=0, hours=0, rate=0, mode="fixed", and taxable=false. Do NOT assign any default rate or price.

MATERIALS:
- Physical goods the client keeps. Extract ONLY the noun/item name, stripping action verbs.
- NAMING: When user says "used nails" or "got filters", the action verb ("used", "got", "bought", "grabbed") is NOT part of the item name. Extract just "Nails", "Filters". Only include adjectives that describe the item itself (e.g., "new filters" → "New Filters", "copper pipe" → "Copper Pipe").
#{target_is_georgian ? '- GEORGIAN NAMING: Keep material names in singular form (e.g., "ნაჯახი" for any quantity). Do NOT pluralize.' : '- TRANSLATION: If the input is in Georgian or any other non-English language, you MUST translate material names to English. E.g., "ნაჯახი" → "Axe", "ლურსმანი" → "Nail", "მილი" → "Pipe". Do NOT leave Georgian text in the name field.'}
- UNIT PRICE RULE: If a total price is given for a quantity (e.g., "4 items cost 60" or "4 axes... but put 60"), set qty=4 and unit_price=60/4. Do NOT assign total as unit_price.
- DISTINCT ITEMS: If user lists multiple named items (e.g. "used nails, used filters"), create SEPARATE material entries for each. Do NOT bundle them as subcategories.
- BUNDLING ONLY: Only bundle into subcategories when user gives a COLLECTIVE total (e.g. "materials were $500" or "parts cost 300 total"). In that case, create ONE item named "Materials" with that price, and list specific part names in 'sub_categories'.
- Extract QUANTITY into the 'qty' field (default 1).
- Extract UNIT PRICE (price per item) into 'unit_price'. If an item has no price mentioned, leave unit_price as null.
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
  "date": null,
  "due_days": null,
  "due_date": null,
  "raw_summary": "",
  "clarifications": [
    { "field": "materials.unit_price", "guess": 795, "question": "You said 'just under 800' for parts. What's the exact amount?" }
  ]
}

----------------------------
FINAL REMINDERS (CRITICAL)
----------------------------
- #{lang_context}
- FREE ITEMS: If user says "უფასოდ", "უფასოდ ჩავუთვლი", "free", "no charge", "on the house" about ANY item, that item MUST have price=0, rate=0, hours=0, mode="fixed", taxable=false. This is NON-NEGOTIABLE.
PROMPT

      instruction_for_cache = normalize_gemini_instruction_for_cache(
        instruction,
        today_for_prompt: today_for_prompt,
        hours_per_workday: hours_per_workday,
        three_days_hours: three_days_hours,
        half_day_hours: half_day_hours
      )
      runtime_cache_context = gemini_runtime_instruction_context(
        today_for_prompt: today_for_prompt,
        hours_per_workday: hours_per_workday,
        three_days_hours: three_days_hours,
        half_day_hours: half_day_hours
      )

      primary_model = ENV["GEMINI_PRIMARY_MODEL"].presence || "gemini-2.5-flash-lite"
      fallback_model = ENV["GEMINI_FALLBACK_MODEL"].presence || "gemini-2.5-flash"
      model_chain = [ primary_model, fallback_model ].map { |m| m.to_s.strip }.reject(&:blank?).uniq.take(2)

      user_input_parts = []

      if is_manual_text
        user_input_parts << { text: "USER INPUT (MANUAL TEXT):\n#{params[:manual_text]}" }
      else
        audio = params[:audio]
        return render json: { error: t('no_audio') }, status: 400 unless audio

        if audio.size > 10.megabytes
          return render json: { error: t('audio_too_large') }, status: 413
        end

        browser_transcript = params[:browser_transcript].to_s.strip
        if browser_transcript.present?
          user_input_parts << {
            text: "BROWSER LIVE TRANSCRIPT (NOISY HINT, MAY CONTAIN ERRORS):\n#{browser_transcript}"
          }
        end

        audio_data = Base64.strict_encode64(audio.read)
        user_input_parts << { inline_data: { mime_type: audio.content_type, data: audio_data } }
      end

      raw = nil
      json = nil
      last_body = {}
      used_model = nil

      model_chain.each_with_index do |gemini_model, idx|
        cache_key, cached_instruction_name = gemini_instruction_cached_content(
          api_key: api_key,
          model: gemini_model,
          instruction: instruction_for_cache
        )
        use_cached_instruction = cached_instruction_name.present?

        prompt_parts = []
        prompt_parts << { text: instruction } unless use_cached_instruction
        prompt_parts << { text: runtime_cache_context } if use_cached_instruction
        prompt_parts.concat(user_input_parts)

        body = gemini_generate_content(
          api_key: api_key,
          model: gemini_model,
          prompt_parts: prompt_parts,
          cached_instruction_name: (use_cached_instruction ? cached_instruction_name : nil)
        )

        if use_cached_instruction && body["error"].present?
          Rails.logger.warn("GEMINI CACHE FALLBACK (#{gemini_model}): #{body["error"].to_json}")
          Rails.cache.delete(cache_key) if cache_key.present?

          fallback_parts = prompt_parts.dup
          fallback_parts.unshift({ text: instruction })

          body = gemini_generate_content(
            api_key: api_key,
            model: gemini_model,
            prompt_parts: fallback_parts,
            cached_instruction_name: nil
          )
        end

        last_body = body

        if body["error"].present?
          Rails.logger.warn("AI MODEL ERROR (#{gemini_model}): #{body["error"].to_json}")
          next
        end

        parts = body.dig("candidates", 0, "content", "parts")
        candidate_raw = parts&.map { |p| p["text"] }&.join("\n")

        if candidate_raw.blank?
          Rails.logger.warn("AI MODEL EMPTY RAW (#{gemini_model}).")
          next
        end

        raw = candidate_raw
        Rails.logger.info "AI RAW RESPONSE (#{gemini_model}): #{raw}"

        # More robust JSON extraction to handle preamble or "thinking" blocks
        json_match = raw.match(/\{[\s\S]*\}/m)
        candidate_json = nil
        if json_match
          begin
            candidate_json = JSON.parse(json_match[0])
          rescue => e
            Rails.logger.error "AI JSON PARSE ERROR (#{gemini_model}): #{e.message}. Raw: #{raw}"
          end
        else
          Rails.logger.error "AI NO JSON FOUND IN RAW (#{gemini_model}): #{raw}"
        end

        if candidate_json
          json = candidate_json
          used_model = gemini_model
          break
        elsif idx < (model_chain.length - 1)
          Rails.logger.warn("AI MODEL FALLBACK: invalid JSON from #{gemini_model}, retrying with #{model_chain[idx + 1]}")
        end
      end

      if raw.blank?
        Rails.logger.error "AI FAILURE: No raw text in response. Body: #{last_body.to_json}"
        return render json: { error: t('ai_failed_response') }, status: 500
      end

      return render json: { error: t('invalid_ai_output') }, status: 422 unless json

      Rails.logger.info "AI MODEL USED: #{used_model || model_chain.first}"

      if json["error"]
        Rails.logger.warn "AI RETURNED ERROR: #{json["error"]}"
        return render json: { error: json["error"] }, status: 422
      end

      Rails.logger.info "AI_PROCESSED: #{json}"

      # Enforce Array Safety
      %w[labor_service_items materials expenses fees credits].each { |k| json[k] = Array(json[k]) }

      # --- POST-PROCESSING: Detect free items from original input ---
      # The AI sometimes ignores free-intent phrases and assigns a price anyway.
      # Scan the original input for free-intent patterns and zero out matching items.
      original_input = (params[:manual_text].presence || params[:browser_transcript].presence || json["raw_summary"]).to_s
      free_kw = /უფასოდ|უფასო|\bfree\b|no charge|complimentary|on the house/i
      if original_input.match?(free_kw)
        # Extract sentences (split on period) that contain a free keyword
        free_sentences = original_input.split(/\./).select { |s| s.match?(free_kw) }
        Rails.logger.info "FREE_DETECT: Found #{free_sentences.size} free sentence(s): #{free_sentences.inspect}"

        # For each labor item, check if it matches any free sentence
        json["labor_service_items"].each do |item|
          next unless item.is_a?(Hash)
          desc = item["desc"].to_s.strip
          desc_lower = desc.downcase

          matched = free_sentences.any? do |sentence|
            s = sentence.downcase.strip
            # 1. Direct: desc text appears in sentence
            s.include?(desc_lower) ||
            # 2. Word match: any significant word from desc appears in sentence
            desc_lower.split(/\s+/).any? { |w| w.length > 2 && s.include?(w) } ||
            # 3. Cross-language: Georgian stem in sentence matches English/Georgian keyword in desc
            [
              ["ფანჯარ", /window|ფანჯ/i], ["ფანჯრ", /window|ფანჯ/i],
              ["მაცივარ", /refrigerator|fridge|მაცივ/i], ["მაცივრ", /refrigerator|fridge|მაცივ/i],
              ["კარებ", /door|კარ/i], ["კარის", /door|კარ/i],
              ["სახურავ", /roof|სახურავ/i], ["ჭერ", /ceiling|ჭერ/i],
              ["შეკეთებ", /repair|შეკეთ/i], ["შეცვლ", /replac|შეცვლ/i],
              ["გათბობ", /heat|გათბობ/i], ["კონდიციონერ", /ac|air.?condition|კონდიც/i],
              ["ონკან", /faucet|tap|ონკან/i], ["საპირფარეშო", /toilet|bathroom|საპირფარეშო/i],
              ["სარკმელ", /window|ფანჯ/i], ["წყალ", /water|plumb|წყალ/i],
              ["ელექტრ", /electr|ელექტრ/i], ["მილ", /pipe|მილ/i]
            ].any? { |stem, pattern| s.include?(stem) && desc_lower.match?(pattern) }
          end

          Rails.logger.info "FREE_DETECT: Item '#{desc}' matched=#{matched}"

          if matched
            Rails.logger.info "FREE_ITEM_OVERRIDE: Zeroing '#{desc}' due to free-intent in input"
            item["price"] = 0
            item["hours"] = 0
            item["rate"] = 0
            item["mode"] = "fixed"
            item["taxable"] = false
          end
        end
      end

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
          "reason" => c["reason"].to_s.strip.presence || I18n.t("courtesy_credit", default: "Courtesy Credit")
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
            "desc" => (target_is_georgian ? "პროფესიონალური მომსახურება" : "Work performed"),
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
          type: "labor",
          title: sec_labels[:labor],
          items: json["labor_service_items"].each_with_index.map do |item, idx|
            if item.is_a?(Hash)
              # Priority: If mode is fixed, use price. If hourly, use hours.
              item_mode = item["mode"].presence || json["billing_mode"] || "hourly"
              free_item = item["desc"].to_s.match?(/\bfree\b|no charge|უფასოდ|უფასო/i) ||
                          (!item["price"].nil? && item["price"].to_f == 0 && item["taxable"] == false)

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

              if free_item
                item_qty_or_amount = 0
                item_rate_val = 0
              end

              {
                desc: item["desc"].to_s.strip,
                price: item_qty_or_amount,
                rate: item_rate_val,
                mode: item_mode,
                # Fix: Inherit from global labor_taxable first, then fall back to scope.
                # If individual item has explicit taxable, use it. Otherwise check global labor_taxable. If still nil, use scope.
                taxable: if free_item
                           false
                         elsif !item["taxable"].nil?
                           to_bool(item["taxable"])
                         elsif !json["labor_taxable"].nil?
                           json["labor_taxable"]
                         else
                           (effective_tax_scope.include?("labor") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
                         end,
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
          type: "materials",
          title: sec_labels[:materials],
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

            # Calculate price first so we can check if it's present
            item_price = clean_num(m["unit_price"])
            # Only apply tax scope if there's actually a price to tax
            item_taxable = if m["taxable"].nil?
                             item_price.present? && item_price > 0 && (effective_tax_scope.include?("material") || effective_tax_scope.include?("product") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
            else
                             to_bool(m["taxable"])
            end

            {
              desc: d_text,
              qty: q_val || 1,
              price: item_price,
              taxable: item_taxable,
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
        expense_items = json["expenses"].map do |e|
          item_price = clean_num(e["price"])
          item_desc = (e["name"].presence || e["desc"].presence || "").to_s.strip
          # Skip items with no description
          next nil if item_desc.blank?

          item_taxable = if e["taxable"].nil?
                           item_price.present? && item_price > 0 && (effective_tax_scope.include?("expense") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
          else
                           to_bool(e["taxable"])
          end
          {
            desc: item_desc,
            price: item_price,
            taxable: item_taxable,
            tax_rate: clean_num(e["tax_rate"]),
            discount_flat: clean_num(e["discount_flat"]),
            discount_percent: clean_num(e["discount_percent"]),
            sub_categories: Array(e["sub_categories"])
          }
        end.compact

        # Only add section if there are valid items
        if expense_items.any?
          json["sections"] << {
            type: "expenses",
            title: sec_labels[:expenses],
            items: expense_items
          }
        end
      end

      # FEES (surcharges - income)
      if json["fees"]&.any?
        fee_items = json["fees"].map do |f|
          item_price = clean_num(f["price"])
          item_desc = (f["name"].presence || f["desc"].presence || "").to_s.strip
          # Skip items with no description
          next nil if item_desc.blank?

          item_taxable = if f["taxable"].nil?
                           item_price.present? && item_price > 0 && (effective_tax_scope.include?("fee") || effective_tax_scope.include?("surcharge") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
          else
                           to_bool(f["taxable"])
          end
          {
            desc: item_desc,
            price: item_price,
            taxable: item_taxable,
            tax_rate: clean_num(f["tax_rate"]),
            discount_flat: clean_num(f["discount_flat"]),
            discount_percent: clean_num(f["discount_percent"]),
            sub_categories: Array(f["sub_categories"])
          }
        end.compact

        # Only add section if there are valid items
        if fee_items.any?
          json["sections"] << {
            type: "fees",
            title: sec_labels[:fees],
            items: fee_items
          }
        end
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
        "date" => json["date"],
        "due_days" => json["due_days"],
        "due_date" => json["due_date"],
        "clarifications" => Array(json["clarifications"]).select { |c| c.is_a?(Hash) && c["question"].present? }
      }

      Rails.logger.info "FINAL NORMALIZED JSON: #{final_response.to_json}"

      render json: final_response

    rescue => e
      Rails.logger.error "AUDIO PROCESSING ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: t("processing_error") }, status: 500
    end
  end


  def gemini_generate_content(api_key:, model:, prompt_parts:, cached_instruction_name: nil)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
    payload = {
      contents: [ { parts: prompt_parts } ]
    }
    payload[:cachedContent] = cached_instruction_name if cached_instruction_name.present?
    req.body = payload.to_json

    res = http.request(req)
    JSON.parse(res.body) rescue {}
  rescue => e
    Rails.logger.error("GEMINI REQUEST ERROR (#{model}): #{e.message}")
    { "error" => { "message" => e.message } }
  end


  def normalize_gemini_instruction_for_cache(instruction, today_for_prompt:, hours_per_workday:, three_days_hours:, half_day_hours:)
    normalized = instruction.to_s.dup

    normalized.gsub!(
      "convert using #{hours_per_workday} hours per day. Examples: \"three days\" = #{three_days_hours} hours, \"half day\" = #{half_day_hours} hours.",
      "convert using HOURS_PER_WORKDAY hours per day. Examples: \"three days\" = HOURS_PER_WORKDAY_x3 hours, \"half day\" = HOURS_PER_WORKDAY_div2 hours."
    )
    normalized.gsub!("Today's date is #{today_for_prompt}.", "Today's date is CURRENT_DATE.")

    normalized
  end


  def gemini_runtime_instruction_context(today_for_prompt:, hours_per_workday:, three_days_hours:, half_day_hours:)
    <<~TEXT.strip
      RUNTIME CONTEXT (overrides cached placeholders):
      - Today's date is #{today_for_prompt}.
      - For day references, use #{hours_per_workday} hours per day.
      - Example conversions: three days = #{three_days_hours} hours, half day = #{half_day_hours} hours.
    TEXT
  end


  def gemini_instruction_cached_content(api_key:, model:, instruction:)
    return [ nil, nil ] if api_key.blank?
    return [ nil, nil ] if ENV["GEMINI_PROMPT_CACHE_ENABLED"].to_s.downcase == "false"

    fingerprint = Digest::SHA256.hexdigest("#{model}\n#{instruction}")
    cache_key = "gemini_instruction_cache:v2:#{fingerprint}"
    cached_name = Rails.cache.read(cache_key).to_s.strip
    return [ cache_key, cached_name ] if cached_name.present?

    uri = URI("https://generativelanguage.googleapis.com/v1beta/cachedContents")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    http.open_timeout = 5

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
    requested_ttl = ENV["GEMINI_PROMPT_CACHE_TTL"].presence || "604800s"
    effective_ttl = requested_ttl

    req.body = {
      model: "models/#{model}",
      contents: [ {
        role: "user",
        parts: [ { text: instruction } ]
      } ],
      ttl: requested_ttl
    }.to_json

    res = http.request(req)
    body = JSON.parse(res.body) rescue {}

    if body["name"].blank? && requested_ttl != "86400s"
      effective_ttl = "86400s"
      req.body = {
        model: "models/#{model}",
        contents: [ {
          role: "user",
          parts: [ { text: instruction } ]
        } ],
        ttl: effective_ttl
      }.to_json
      res = http.request(req)
      body = JSON.parse(res.body) rescue {}
    end

    created_name = body["name"].to_s.strip

    if created_name.present?
      local_expiry = (effective_ttl == "86400s") ? 20.hours : 6.days
      Rails.cache.write(cache_key, created_name, expires_in: local_expiry)
      return [ cache_key, created_name ]
    end

    Rails.logger.warn("GEMINI CACHE CREATE FAILED: #{body.to_json}")
    [ cache_key, nil ]
  rescue => e
    Rails.logger.warn("GEMINI CACHE ERROR: #{e.message}")
    [ nil, nil ]
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

  def paddle_api_base_url
    paddle_env = ENV["PADDLE_ENVIRONMENT"].to_s.downcase
    use_sandbox = paddle_env == "sandbox" || (paddle_env.blank? && !Rails.env.production?)
    use_sandbox ? "https://sandbox-api.paddle.com" : "https://api.paddle.com"
  end

  def paddle_transaction_details(api_key:, transaction_id:)
    urls = paddle_api_base_urls
    saw_forbidden = false

    urls.each do |base_url|
      uri = URI("#{base_url}/transactions/#{CGI.escape(transaction_id.to_s)}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        body = JSON.parse(resp.body) rescue {}
        data = body["data"]
        return data if data.present?
      else
        saw_forbidden ||= resp.code.to_i == 403
        Rails.logger.info("PADDLE TRANSACTION LOOKUP non-success: host=#{uri.host} code=#{resp.code}")
      end
    end

    saw_forbidden ? :forbidden : nil
  rescue => e
    Rails.logger.warn("PADDLE TRANSACTION LOOKUP ERROR: #{e.message}")
    nil
  end

  def alternate_paddle_api_base_url
    paddle_api_base_url == "https://sandbox-api.paddle.com" ? "https://api.paddle.com" : "https://sandbox-api.paddle.com"
  end

  def paddle_customer_portal_url(api_key:, customer_id:)
    return nil if customer_id.blank?

    last_status = nil

    paddle_api_base_urls.each do |base_url|
      uri = URI("#{base_url}/customers/#{CGI.escape(customer_id.to_s)}/portal-sessions")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        body = JSON.parse(resp.body) rescue {}
        data = body["data"] || {}
        url = data["url"].presence ||
          data.dig("urls", "general", "overview").presence ||
          data.dig("urls", "overview").presence ||
          data.dig("urls", "general").presence
        return url if url.present?

        Rails.logger.warn("PADDLE PORTAL SESSION missing URL: host=#{uri.host}")
      else
        last_status = resp.code.to_i
        body_snippet = resp.body.to_s.gsub(/\s+/, " ")[0, 300]
        Rails.logger.warn("PADDLE PORTAL SESSION non-success: host=#{uri.host} code=#{resp.code} body=#{body_snippet}")
      end
    end

    return :forbidden if [ 401, 403 ].include?(last_status)
    return :customer_missing if last_status == 404

    nil
  rescue => e
    Rails.logger.warn("PADDLE PORTAL SESSION ERROR: #{e.message}")
    nil
  end

  def paddle_customer_id_for_subscription(api_key:, subscription_id:)
    uri = URI("#{paddle_api_base_url}/subscriptions/#{CGI.escape(subscription_id.to_s)}")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{api_key}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 8
    http.open_timeout = 5

    resp = http.request(req)
    return nil unless resp.is_a?(Net::HTTPSuccess)

    body = JSON.parse(resp.body) rescue {}
    body.dig("data", "customer_id").to_s.presence
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION LOOKUP ERROR: #{e.message}")
    nil
  end

  def profile_paddle_customer_id(profile)
    return nil unless profile.respond_to?(:paddle_customer_id)

    profile.paddle_customer_id.to_s.presence
  end

  def load_subscription_billing_data(profile)
    @billing_payment_method_label = t("subscription_page.not_available")
    @billing_last_payment_label = t("subscription_page.not_available")
    @billing_history_rows = []
    @billing_next_billing_label = nil
    @billing_next_charge_label = nil

    return if profile.blank?

    cached_snapshot = read_subscription_billing_cache(profile)
    if cached_snapshot.present?
      @billing_payment_method_label = cached_snapshot[:payment_method] if cached_snapshot[:payment_method].present?
      @billing_last_payment_label = cached_snapshot[:last_payment] if cached_snapshot[:last_payment].present?
      @billing_history_rows = normalize_billing_history_rows(cached_snapshot[:history_rows])
      @billing_next_billing_label = cached_snapshot[:next_billing] if cached_snapshot[:next_billing].present?
      @billing_next_charge_label = cached_snapshot[:next_charge] if cached_snapshot[:next_charge].present?
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    return if api_key.blank?

    customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
    return if customer_id.blank?

    payment_method = paddle_customer_payment_method(api_key: api_key, customer_id: customer_id)
    @billing_payment_method_label = payment_method if payment_method.present?

    rows = paddle_customer_transactions(api_key: api_key, customer_id: customer_id, limit: 50)
    history_rows = normalize_billing_history_rows(rows)
    @billing_history_rows = history_rows if history_rows.present?

    subscription_data = paddle_subscription_data(api_key: api_key, subscription_id: profile.paddle_subscription_id)
    if subscription_data.present?
      next_billed_at = parse_paddle_time(subscription_data["next_billed_at"] || subscription_data["next_billing_at"])
      @billing_next_billing_label = l(next_billed_at, format: :long) if next_billed_at.present?

      next_charge_label = paddle_subscription_next_charge_label(subscription_data)
      @billing_next_charge_label = next_charge_label if next_charge_label.present?
    end

    if @billing_next_billing_label.blank? || @billing_next_charge_label.blank?
      upcoming_row = rows.find { |row| billing_upcoming_status?(row[:status_raw]) }
      if upcoming_row.present?
        if @billing_next_billing_label.blank? && upcoming_row[:date].present? && upcoming_row[:date] != t("subscription_page.not_available")
          @billing_next_billing_label = upcoming_row[:date]
        end

        if @billing_next_charge_label.blank? && upcoming_row[:amount].present? && upcoming_row[:amount] != t("subscription_page.not_available")
          @billing_next_charge_label = upcoming_row[:amount]
        end
      end
    end

    if @billing_payment_method_label == t("subscription_page.not_available")
      transaction_method = rows.find { |row| row[:payment_method_label].present? }&.dig(:payment_method_label)
      @billing_payment_method_label = transaction_method if transaction_method.present?

      if @billing_payment_method_label == t("subscription_page.not_available")
        candidate_tx_id = rows.find { |row| row[:status_kind] == "completed" }&.dig(:id) || rows.first&.dig(:id)
        if candidate_tx_id.present?
          tx_details = paddle_transaction_details(api_key: api_key, transaction_id: candidate_tx_id)
          if tx_details.is_a?(Hash)
            detailed_method = paddle_payment_method_label_from_transaction(tx_details)
            @billing_payment_method_label = detailed_method if detailed_method.present?
          end
        end
      end
    end

    latest_paid = rows.find { |row| row[:status_kind] == "completed" }
    if latest_paid.present?
      @billing_last_payment_label = "#{latest_paid[:amount]} · #{latest_paid[:date]}"
    end

    has_real_payment_method = @billing_payment_method_label.present? && @billing_payment_method_label != t("subscription_page.not_available")
    has_real_last_payment = @billing_last_payment_label.present? && @billing_last_payment_label != t("subscription_page.not_available")
    has_real_next_billing = @billing_next_billing_label.present? && @billing_next_billing_label != t("subscription_page.not_available")
    has_real_next_charge = @billing_next_charge_label.present? && @billing_next_charge_label != t("subscription_page.not_available")

    if has_real_payment_method || has_real_last_payment || @billing_history_rows.present? || has_real_next_billing || has_real_next_charge
      write_subscription_billing_cache(
        profile: profile,
        payment_method: @billing_payment_method_label,
        last_payment: @billing_last_payment_label,
        history_rows: @billing_history_rows,
        next_billing: @billing_next_billing_label,
        next_charge: @billing_next_charge_label
      )
    end
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING DATA ERROR: #{e.message}")
  end

  def resolve_paddle_customer_id(profile:, api_key:)
    customer_id = profile_paddle_customer_id(profile)
    if customer_id.blank? && profile.paddle_subscription_id.present?
      customer_id = paddle_customer_id_for_subscription(api_key: api_key, subscription_id: profile.paddle_subscription_id)
    end

    if customer_id.blank?
      email = profile.paddle_customer_email.presence || profile.email.presence || profile.user&.email
      customer_id = paddle_customer_id_for_email(api_key: api_key, email: email)
    end

    if customer_id.present? && profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.blank?
      profile.update_columns(paddle_customer_id: customer_id)
    end

    customer_id
  end

  def paddle_customer_id_for_email(api_key:, email:)
    return nil if email.blank?

    body = paddle_get_json(api_key: api_key, path: "/customers", params: { email: email })
    customers = paddle_collection_data(body)
    customer = customers.find do |item|
      item_email = item["email"].to_s
      item_email.present? && item_email.casecmp(email.to_s).zero?
    end

    customer&.dig("id").to_s.presence
  rescue => e
    Rails.logger.warn("PADDLE CUSTOMER LOOKUP BY EMAIL ERROR: #{e.message}")
    nil
  end

  def paddle_customer_payment_method(api_key:, customer_id:)
    return nil if customer_id.blank?

    body = paddle_get_json(
      api_key: api_key,
      path: "/customers/#{CGI.escape(customer_id.to_s)}/payment-methods",
      params: { per_page: 1 }
    )
    method = paddle_collection_data(body).first

    if method.blank? && body.is_a?(Hash)
      body = paddle_get_json(
        api_key: api_key,
        path: "/payment-methods",
        params: { customer_id: customer_id, per_page: 1 }
      )
      method = paddle_collection_data(body).first
    end

    return nil if method.blank?

    brand = method["card_brand"].presence ||
      method.dig("card", "brand").presence ||
      method.dig("details", "card", "brand").presence ||
      method.dig("card_details", "brand").presence
    last4 = method["last4"].presence ||
      method.dig("card", "last4").presence ||
      method.dig("details", "card", "last4").presence ||
      method.dig("card_details", "last4").presence
    type = method["type"].presence ||
      method["payment_method_type"].presence ||
      method.dig("details", "type").presence

    if brand.present? && last4.present?
      "#{brand.to_s.titleize} •••• #{last4}"
    elsif type.present?
      type.to_s.titleize
    end
  rescue => e
    Rails.logger.warn("PADDLE PAYMENT METHOD LOOKUP ERROR: #{e.message}")
    nil
  end

  def paddle_customer_transactions(api_key:, customer_id:, limit: 10)
    return [] if customer_id.blank?

    body = paddle_get_json(
      api_key: api_key,
      path: "/transactions",
      params: { customer_id: customer_id, per_page: limit }
    )
    transactions = paddle_collection_data(body)

    if transactions.blank? && body.is_a?(Hash)
      body = paddle_get_json(
        api_key: api_key,
        path: "/transactions",
        params: { "customer_id[]" => customer_id, per_page: limit }
      )
      transactions = paddle_collection_data(body)
    end

    rows = transactions.map do |tx|
      billed_at = parse_paddle_time(tx["billed_at"] || tx["created_at"] || tx["updated_at"])
      date_label = billed_at.present? ? l(billed_at, format: :long) : t("subscription_page.not_available")
      status_raw = tx["status"].to_s.downcase
      status_kind = billing_history_status_kind(status_raw)
      status_label = if status_kind == "completed"
        "Completed"
      elsif status_kind == "failed"
        "Failed"
      elsif status_raw.present?
        status_raw.humanize
      else
        t("subscription_page.not_available")
      end
      amount_label = format_paddle_transaction_amount(tx)
      receipt_url = tx["invoice_url"].presence || tx["receipt_url"].presence || tx.dig("invoice", "url").presence

      {
        id: tx["id"].to_s,
        date: date_label,
        amount: amount_label,
        status: status_label,
        status_kind: status_kind,
        status_raw: status_raw,
        receipt_url: receipt_url,
        payment_method_label: paddle_payment_method_label_from_transaction(tx)
      }
    end.compact

    rows.first(limit)
  rescue => e
    Rails.logger.warn("PADDLE TRANSACTIONS LIST ERROR: #{e.message}")
    []
  end

  def billing_history_status_kind(status_raw)
    raw = status_raw.to_s.downcase
    return "completed" if %w[completed complete paid billed succeeded successful success processed settled].include?(raw)
    return "failed" if %w[failed failure past_due past-due canceled cancelled declined refused rejected error].include?(raw)

    nil
  end

  def billing_upcoming_status?(status_raw)
    %w[ready draft incomplete pending scheduled].include?(status_raw.to_s.downcase)
  end

  def paddle_subscription_data(api_key:, subscription_id:)
    return {} if subscription_id.blank?

    body = paddle_get_json(api_key: api_key, path: "/subscriptions/#{CGI.escape(subscription_id.to_s)}")
    body.is_a?(Hash) ? (body["data"] || {}) : {}
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION DATA LOOKUP ERROR: #{e.message}")
    {}
  end

  def paddle_subscription_next_charge_label(subscription_data)
    return nil unless subscription_data.is_a?(Hash)

    item = Array(subscription_data["items"]).first || {}
    price = item["price"] || {}
    unit_price = price["unit_price"]
    next_transaction = subscription_data["next_transaction"] || {}

    amount = if unit_price.is_a?(Hash)
      unit_price["amount"]
    else
      unit_price.presence
    end
    amount ||= next_transaction.dig("details", "totals", "grand_total")
    amount ||= next_transaction.dig("details", "totals", "total")

    currency = if unit_price.is_a?(Hash)
      unit_price["currency_code"]
    else
      nil
    end
    currency ||= price["currency_code"]
    currency ||= next_transaction.dig("details", "totals", "currency_code")
    currency ||= next_transaction["currency_code"]
    currency ||= subscription_data["currency_code"]

    return nil if amount.blank?

    format_paddle_money(amount: amount, currency: currency.presence || "USD")
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION NEXT CHARGE PARSE ERROR: #{e.message}")
    nil
  end

  def paddle_payment_method_label_from_transaction(transaction)
    return nil unless transaction.is_a?(Hash)

    payments = transaction["payments"]
    first_payment = payments.is_a?(Array) ? payments.first : nil
    method_details = first_payment&.dig("method_details") || {}
    method_details_card = method_details.is_a?(Hash) ? (method_details["card"] || {}) : {}

    brand = method_details["card_brand"] ||
      method_details["brand"] ||
      method_details_card["brand"] ||
      transaction.dig("billing_details", "payment_method", "card_brand") ||
      transaction.dig("billing_details", "card", "brand")
    last4 = method_details["last4"] ||
      method_details["card_last4"] ||
      method_details_card["last4"] ||
      transaction.dig("billing_details", "payment_method", "last4") ||
      transaction.dig("billing_details", "card", "last4")
    type = method_details["type"] ||
      first_payment&.dig("method") ||
      transaction.dig("billing_details", "payment_method", "type") ||
      transaction["payment_method_type"] ||
      transaction["collection_mode"]

    if brand.present? && last4.present?
      "#{brand.to_s.titleize} •••• #{last4}"
    elsif type.present?
      type.to_s.tr("_", " ").titleize
    end
  end

  def paddle_invoice_receipt_url(api_key:, invoice_id:)
    return nil if invoice_id.blank?

    body = paddle_get_json(api_key: api_key, path: "/invoices/#{CGI.escape(invoice_id.to_s)}")
    data = body.is_a?(Hash) ? (body["data"] || {}) : {}

    data["url"].presence ||
      data["hosted_url"].presence ||
      data["download_url"].presence ||
      data["pdf_download_url"].presence
  rescue => e
    Rails.logger.warn("PADDLE INVOICE URL LOOKUP ERROR: #{e.message}")
    nil
  end

  def format_paddle_transaction_amount(transaction)
    totals = transaction.dig("details", "totals") || transaction["totals"] || {}
    amount = totals["grand_total"].presence || totals["total"].presence || transaction["amount"].presence
    currency = totals["currency_code"].presence || transaction["currency_code"].presence || "USD"

    format_paddle_money(amount: amount, currency: currency)
  end

  def format_paddle_money(amount:, currency:)
    return t("subscription_page.not_available") if amount.blank?

    amount_string = amount.to_s
    major_amount =
      if amount_string.include?(".")
        amount_string.to_f
      else
        amount_string.to_f / 100.0
      end

    "#{currency.to_s.upcase} #{format('%.2f', major_amount)}"
  rescue
    t("subscription_page.not_available")
  end

  def parse_paddle_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue
    nil
  end

  def paddle_collection_data(body)
    return [] unless body.is_a?(Hash)

    data = body["data"]
    data.is_a?(Array) ? data : []
  end

  def paddle_api_base_urls
    paddle_env = ENV["PADDLE_ENVIRONMENT"].to_s.downcase
    primary = paddle_api_base_url

    return [ primary ] if [ "sandbox", "production", "live" ].include?(paddle_env)

    [ primary, alternate_paddle_api_base_url ].compact.uniq
  end

  def paddle_get_json(api_key:, path:, params: {})
    return nil if api_key.blank?

    paddle_api_base_urls.each do |base_url|
      uri = URI("#{base_url}#{path}")
      filtered_params = params.to_h.reject { |_, value| value.blank? }
      uri.query = URI.encode_www_form(filtered_params) if filtered_params.present?

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        return JSON.parse(resp.body) rescue {}
      end

      if resp.code.to_i == 429
        Rails.logger.warn("PADDLE GET rate-limited: path=#{path} host=#{uri.host} code=#{resp.code}")
        return nil
      end

      Rails.logger.info("PADDLE GET non-success: path=#{path} host=#{uri.host} code=#{resp.code}")
    end

    nil
  rescue => e
    Rails.logger.warn("PADDLE GET ERROR (#{path}): #{e.message}")
    nil
  end

  def read_subscription_billing_cache(profile)
    return nil if profile.blank?

    cache_key = subscription_billing_cache_key(profile)
    snapshot = Rails.cache.read(cache_key)
    return nil unless snapshot.is_a?(Hash)

    {
      payment_method: snapshot[:payment_method].presence || snapshot["payment_method"].presence,
      last_payment: snapshot[:last_payment].presence || snapshot["last_payment"].presence,
      history_rows: normalize_billing_history_rows(snapshot[:history_rows] || snapshot["history_rows"]),
      next_billing: snapshot[:next_billing].presence || snapshot["next_billing"].presence,
      next_charge: snapshot[:next_charge].presence || snapshot["next_charge"].presence
    }
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING CACHE READ ERROR: #{e.message}")
    nil
  end

  def write_subscription_billing_cache(profile:, payment_method:, last_payment:, history_rows:, next_billing: nil, next_charge: nil)
    return if profile.blank?

    payload = {
      payment_method: payment_method,
      last_payment: last_payment,
      history_rows: normalize_billing_history_rows(history_rows),
      next_billing: next_billing,
      next_charge: next_charge
    }

    Rails.cache.write(subscription_billing_cache_key(profile), payload, expires_in: 12.hours)
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING CACHE WRITE ERROR: #{e.message}")
  end

  def subscription_billing_cache_key(profile)
    identifier = profile.user_id.presence || profile.id
    "subscription:billing:snapshot:#{identifier}"
  end

  def normalize_billing_history_rows(rows)
    Array(rows).filter_map do |row|
      hash = row.is_a?(Hash) ? row.with_indifferent_access : nil
      next if hash.blank?

      status_raw = hash[:status_raw].to_s.downcase
      status_raw = hash[:status].to_s.downcase if status_raw.blank?
      status_kind = hash[:status_kind].presence || billing_history_status_kind(status_raw)
      next if status_kind.blank?

      {
        id: hash[:id].to_s,
        date: hash[:date].presence || t("subscription_page.not_available"),
        amount: hash[:amount].presence || t("subscription_page.not_available"),
        status: status_kind == "completed" ? "Completed" : "Failed",
        status_kind: status_kind,
        status_raw: status_raw,
        receipt_url: hash[:receipt_url].presence,
        payment_method_label: hash[:payment_method_label].presence
      }
    end.first(10)
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
      :note,
      :billing_mode,
      :currency,
      :invoice_style,
      :discount_tax_rule,
      :remove_logo,
      :logo,
      :accent_color,
      :system_language,
      :document_language,
      :transcription_language
    )
  end
end
