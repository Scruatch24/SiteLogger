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
      # FIXED: Redirect back to settings instead of root
      redirect_to settings_path, notice: "Profile saved successfully!"
    else
      render :settings, status: :unprocessable_entity
    end
  end

  def process_audio
    api_key = ENV['GEMINI_API_KEY']
    is_manual_text = params[:manual_text].present?
    
    begin 
      # 1. DEFINE THE UNIVERSAL PROMPT LOGIC
      universal_instruction = "Analyze this field report.
        1. Extract 'client', 'time' (hours), and 'date'.
        2. DETECT THE INDUSTRY: Is this Construction? IT? Agriculture? Medical? Cleaning?
        3. Create 2-4 professional section titles RELEVANT TO THAT INDUSTRY.
           - Example (Construction): 'Work Performed', 'Materials Used', 'Safety Hazards'.
           - Example (IT): 'Systems Checked', 'Hardware Replaced', 'Pending Issues'.
           - Example (Farming): 'Crop Health', 'Chemicals Applied', 'Weather Conditions'.
        4. Group the extracted items into these sections.
        5. STRICT JSON FORMAT:
        {
          \"client\": \"...\",
          \"time\": \"...\",
          \"date\": \"...\",
          \"raw_summary\": \"...\",
          \"sections\": [
            { \"title\": \"(Contextual Title)\", \"items\": [ { \"desc\": \"...\", \"qty\": \"...\" } ] }
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
          { text: "#{universal_instruction} 
                 1. Transcribe audio into 'raw_summary'.
                 2. If audio is silent/unclear, return: { \"error\": \"Audio unclear\" }" },
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
        json_match = raw_text.match(/\{.*\}/m)
        parsed_json = JSON.parse(json_match[0])
        
        if is_manual_text
          parsed_json['raw_summary'] ||= params[:manual_text]
        end

        # Validation Gate
        if parsed_json["error"] || (parsed_json["raw_summary"].to_s.strip.length < 2)
          error_msg = parsed_json["error"] || "AI could not detect enough info to log."
          render json: { error: error_msg }, status: 422
          return
        end

        render json: parsed_json
      else
        render json: { error: "AI failed to process. Try again." }, status: 500
      end

    rescue => e
      render json: { error: "Server Error: #{e.message}" }, status: 500
    end
  end

  # --- PRIVATE METHODS ---
  private

  def profile_params
    # SINGLE DEFINITION with all required fields
    params.require(:profile).permit(:business_name, :phone, :email, :address, :tax_id, :hourly_rate, :tax_rate, :payment_instructions)
  end
end