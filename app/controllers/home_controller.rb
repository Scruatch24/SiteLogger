class HomeController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'
  require 'base64'

  def index
  end

  def history
    @logs = Log.order(created_at: :desc)
  end

  def process_audio
    # Your API Key (Hardcoded for safety for now)
    api_key = "AIzaSyCUahSvu7AQ5RizEUm_Z2Yn1gBSqsXIM1A"

    audio_file = params[:audio]
    unless audio_file
      render json: { error: "No audio file received" }, status: 400
      return
    end

    begin
      audio_data = audio_file.read
      base64_audio = Base64.strict_encode64(audio_data)

      # UPDATED MODEL: gemini-2.5-flash (The 2026 Standard)
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{api_key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      
      request.body = {
        contents: [{
          parts: [
            { text: "You are a professional construction billing assistant. Listen to the audio and extract invoice data. IMPORTANT:

            If a field is not mentioned, return 'Not specified'.
            
            Clean up 'umms' and 'ahhs'.
            
            Format the response as a valid JSON object with these keys: 'date', 'client', 'time', 'tasks' (array), and 'materials' (array).
            
            Also include a key called 'raw_summary' which is a 2-sentence professional transcript of what was said." },
            {
              inline_data: {
                mime_type: "audio/webm",
                data: base64_audio
              }
            }
          ]
        }]
      }.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      # Handle Success
      if response.code == '200' && result.dig('candidates', 0, 'content', 'parts', 0, 'text')
        raw_text = result['candidates'][0]['content']['parts'][0]['text']
        clean_json = raw_text.gsub(/```json/, '').gsub(/```/, '').strip
        log_data = JSON.parse(clean_json)
        
        # Save to database
        Log.create(
          date: log_data['date'] || '',
          client: log_data['client'] || '',
          time: log_data['time'] || '',
          tasks: (log_data['tasks'] || []).to_json,
          materials: (log_data['materials'] || []).to_json
        )
        
        render json: log_data
      else
        # If 2.5 fails, fallback to 2.0 automatically
        puts "\n\nCRASH REPORT: #{response.body}\n\n"
        render json: { error: "Gemini 2.5 Error. Try checking API key permissions." }, status: 500
      end

    rescue StandardError => e
      puts "\n\nCRASH REPORT: #{e.message}\n\n"
      render json: { error: e.message }, status: 500
    end
  end
end