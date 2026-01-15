class HomeController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'
  require 'base64'

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
    api_key = ENV['GEMINI_API_KEY']
    is_manual_text = params[:manual_text].present?
    
    # We grab the current mode from the profile (set by before_action :set_profile)
    # This informs the AI of the context before it starts processing.
    mode = @profile.billing_mode || "hourly"
    
    begin 
      universal_instruction = "You are a STRICT Data Intake Validator.
        
        STEP 1: LISTEN CAREFULLY.
        - If the audio is silent, static, clicks, or background noise: STOP. Return { \"error\": \"Audio was unclear. Please speak closer to the mic.\" }
        - If the audio provides NO specific work details (e.g. just 'hello'): STOP. Return { \"error\": \"No work details detected.\" }
        
        STEP 2: CHECK FOR HALLUCINATIONS.
        - Do NOT make up names, dates, or quantities.
        - If you are about to make up a fake report because you didn't hear anything: STOP. Return { \"error\": \"Audio unclear\" }

        STEP 3: EXTRACT REAL DATA.
        - Current Billing Mode: #{mode.upcase}
        
        - STRICT RULE FOR 'TIME' FIELD:
          1. If Mode is HOURLY: Extract ONLY the numeric hours (e.g., '3.5'). Ignore dollar signs.
          2. If Mode is FIXED: 
             - IGNORE all mentions of duration, hours, or how long the job took.
             - ONLY extract a value for 'time' if the user explicitly mentions a PRICE or COST (e.g., 'Charge 500' or 'Price is 200').
             - If NO explicit price is mentioned, return \"\" (empty string) for 'time'.
        
        - DETECT THE INDUSTRY (Construction, IT, Farming, etc).
        - Create 2-4 professional section titles.
        
        STRICT JSON OUTPUT:
        {
          \"client\": \"...\",
          \"time\": \"...\",
          \"date\": \"...\",
          \"raw_summary\": \"...\",
          \"sections\": [
            { \"title\": \"...\", \"items\": [ { \"desc\": \"...\", \"qty\": \"...\" } ] }
          ]
        }"

      if is_manual_text
        prompt_parts = [{ 
          text: "#{universal_instruction} 
                 IMPORTANT: The 'raw_summary' field must contain the original text provided below.
                 TEXT: #{params[:manual_text]}" 
        }]
      else
        audio_file = params[:audio]
        return render json: { error: "No audio" }, status: 400 unless audio_file
        
        audio_data = Base64.strict_encode64(audio_file.read)
        prompt_parts = [
          { text: "TRANSCRIPT: Generate a verbatim transcript of this audio. Then apply the validation rules below.\n#{universal_instruction}" },
          { inline_data: { mime_type: audio_file.content_type, data: audio_data } }
        ]
      end

      uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port).tap { |h| h.use_ssl = true }
      http.open_timeout = 60 
      http.read_timeout = 60 

      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = { contents: [{ parts: prompt_parts }] }.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code == '200' && result.dig('candidates', 0, 'content', 'parts', 0, 'text')
        raw_text = result['candidates'][0]['content']['parts'][0]['text']
        cleaned_text = raw_text.gsub(/```json/, '').gsub(/```/, '')
        json_match = cleaned_text.match(/\{.*\}/m)
        
        if json_match
          parsed_json = JSON.parse(json_match[0])
          
          # Numeric safety net: Only triggers if the AI actually found a value
          if parsed_json["time"].present? && parsed_json["time"] != ""
            numeric_time = parsed_json["time"].to_s.scan(/\d+\.?\d*/).first
            parsed_json["time"] = numeric_time || ""
          end
        else
          render json: { error: "Audio unclear. Please try again." }, status: 422
          return
        end
        
        if is_manual_text
          parsed_json['raw_summary'] ||= params[:manual_text]
        end

        summary_len = parsed_json["raw_summary"].to_s.strip.length
        
        if parsed_json["error"]
          render json: { error: parsed_json["error"] }, status: 422
          return
        elsif summary_len < 10
          render json: { error: "No speech detected." }, status: 422
          return
        end

        render json: parsed_json
      else
        render json: { error: "AI connection failed." }, status: 500
      end

    rescue => e
      render json: { error: "Server Error: #{e.message}" }, status: 500
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
      :payment_instructions,
      :billing_mode, # <--- This allows the "Fixed vs Hourly" toggle to save
      :currency
    )
  end
end