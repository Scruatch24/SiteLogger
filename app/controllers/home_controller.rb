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

        PER-ITEM TAXABLE OVERRIDES (CRITICAL):
        - If user says "only [item] is taxable":
          - Set "taxable": true for that specific item.
          - Set "taxable": false for ALL OTHER items (tasks and materials).
        - If no "only" constraint:
          - Set "taxable": null (allow default logic).

        PRICING RULES:
        - Extract prices even if phrased as "around $40", "should be $40", "costs $40".
        - unit_price must be a number (e.g. 40.0).

        AUDIO VALIDATION:
        - If audio is silent or unclear → return {"error":"Audio unclear"}
        - If no work details → return {"error":"No work details detected"}

        TIME RULES (CRITICAL):
        - Only extract time if duration words exist:
          ("hour", "hours", "minutes", "half", "quarter")
        - Convert:
          "hour and a half" → 1.5
          "hour fifteen" → 1.25
          "45 minutes" → 0.75
        - IGNORE numbers related to:
          prices, materials, quantities, addresses
        - If unsure → return empty string

        BILLING MODE: #{mode.upcase}

        MATERIAL VS TASK RULES:
        - List materials in "materials" array.
        - Do NOT list the *installation* of those same materials as a separate "task" unless it involves complex labor distinct from the main time.
        - "tasks" should be high-level summaries of work done (e.g., "Monthly maintenance").

        OUTPUT STRICT JSON ONLY:

        {
          "client": "",
          "address": "",
          "labor_hours": "",
          "fixed_price": "",
          "tax_scope": "",
          "materials": [
            { "name": "", "qty": "", "unit_price": "", "taxable": null }
          ],
          "tasks": [
            { "desc": "", "taxable": null }
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

      # ---------- NORMALIZATION ----------
      hours = json["labor_hours"].to_s.strip
      price = json["fixed_price"].to_s.strip

      effective_tax_scope =
        json["tax_scope"].to_s.strip.presence ||
          @profile.tax_scope.to_s.strip.presence ||
          "total"

      json["tax_scope"] = effective_tax_scope

      json["time"] =
        if mode == "fixed"
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
              { desc: t["desc"], taxable: t["taxable"] }
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
              qty: m["qty"].presence || "1",
              price: m["unit_price"],
              taxable: m["taxable"]
            }
          end
        }
      end

      json["raw_summary"] ||= params[:manual_text]
      json.slice!("client", "time", "raw_summary", "sections", "tax_scope")

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
