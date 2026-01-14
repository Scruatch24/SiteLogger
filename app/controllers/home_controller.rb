class HomeController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'
  require 'base64'

  # --- PUBLIC METHODS ---

  def index
  end

  def history
    @logs = Log.order(created_at: :desc)
  end

  def settings
    @profile = Profile.first || Profile.new
  end

  def save_settings
    @profile = Profile.first || Profile.new
    
    # Use assign_attributes + save to handle both New and Existing profiles gracefully
    @profile.assign_attributes(profile_params)
    
    if @profile.save
      # Redirect back to settings so user sees their changes saved
      redirect_to settings_path, notice: "Profile saved successfully!"
    else
      render :settings, status: :unprocessable_entity
    end
  end

  def process_audio
    api_key = ENV['GEMINI_API_KEY']
    is_manual_text = params[:manual_text].present?
    
    begin 
      # 1. DEFINE THE STRICT VALIDATOR LOGIC
      # This replaces the old "Analyze this..." prompt to stop hallucinations.
      
      universal_instruction = "You are a STRICT Data Intake Validator.
        
        STEP 1: LISTEN CAREFULLY.
        - If the audio is silent, static, clicks, or background noise: STOP. Return { \"error\": \"Audio was unclear. Please speak closer to the mic.\" }
        - If the audio provides NO specific work details (e.g. just 'hello'): STOP. Return { \"error\": \"No work details detected.\" }
        
        STEP 2: CHECK FOR HALLUCINATIONS.
        - Do NOT make up names like 'Smith Corp', 'Green Valley Farms', or 'Acme'. 
        - Do NOT invent a time (like '9:00 AM') if not stated.
        - Do NOT invent quantities.
        - If you are about to make up a fake report because you didn't hear anything: STOP. Return { \"error\": \"Audio unclear\" }

        STEP 3: EXTRACT REAL DATA.
        - Only if you passed Step 1 and 2, extract 'client', 'time' (hours), and 'date'.
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
        # We explicitly ask for a verbatim transcript first to force the AI to realize there is no speech.
        prompt_parts = [
          { text: "TRANSCRIPT: Generate a verbatim transcript of this audio. Then apply the validation rules below.\n#{universal_instruction}" },
          { inline_data: { mime_type: audio_file.content_type, data: audio_data } }
        ]
      end

      # 2. CALL THE API
      uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port).tap { |h| h.use_ssl = true }
      http.open_timeout = 60 
      http.read_timeout = 60 

      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = { contents: [{ parts: prompt_parts }] }.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      # 3. HANDLE RESPONSE
      if response.code == '200' && result.dig('candidates', 0, 'content', 'parts', 0, 'text')
        raw_text = result['candidates'][0]['content']['parts'][0]['text']
        
        # Clean the response (remove ```json markdown if present)
        cleaned_text = raw_text.gsub(/```json/, '').gsub(/```/, '')
        
        json_match = cleaned_text.match(/\{.*\}/m)
        
        if json_match
          parsed_json = JSON.parse(json_match[0])
        else
          render json: { error: "Audio unclear. Please try again." }, status: 422
          return
        end
        
        if is_manual_text
          parsed_json['raw_summary'] ||= params[:manual_text]
        end

        # --- THE HALLUCINATION TRAP ---
        # If the AI returns a "Perfect" report but the raw_summary is empty/short, it's lying.
        summary_len = parsed_json["raw_summary"].to_s.strip.length
        
        if parsed_json["error"]
          error_msg = parsed_json["error"]
          render json: { error: error_msg }, status: 422
          return
        elsif summary_len < 10
          # TRAP: If summary is < 10 chars, it's impossible to have a full report.
          # The AI likely hallucinated the sections while leaving the summary empty.
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

  # --- PRIVATE METHODS ---
  private

  def profile_params
    # Ensures all Settings fields (including Tax Rate & Instructions) are permitted
    params.require(:profile).permit(:business_name, :phone, :email, :address, :tax_id, :hourly_rate, :tax_rate, :payment_instructions)
  end
end