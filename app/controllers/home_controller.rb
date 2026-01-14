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
    # RE-ENTER YOUR KEY HERE
    api_key = ENV['GEMINI_API_KEY']

    audio_file = params[:audio]
    return render json: { error: "No audio file" }, status: 400 unless audio_file

    begin
      audio_data = audio_file.read
      base64_audio = Base64.strict_encode64(audio_data)

      # Using 1.5-PRO for maximum accuracy
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=#{api_key}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      
      request.body = {
        contents: [{
          parts: [
            { text: "You are a specialized construction scribe. Listen to the audio and extract data into JSON.
                     REQUIRED KEYS:
                     - 'client': name of the person or company
                     - 'time': duration of work
                     - 'tasks': array of work done
                     - 'materials': array of items used
                     - 'date': the date mentioned or today's date
                     - 'raw_summary': A 1-sentence transcript of what was actually said.
                     
                     If you don't hear a specific field, put 'Not mentioned'. 
                     Output ONLY raw JSON. No markdown blocks." 
            },
            { inline_data: { mime_type: "audio/webm", data: base64_audio } }
          ]
        }]
      }.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code == '200' && result.dig('candidates', 0, 'content', 'parts', 0, 'text')
        raw_text = result['candidates'][0]['content']['parts'][0]['text']
        clean_json = raw_text.gsub(/```json/, '').gsub(/```/, '').strip
        render json: JSON.parse(clean_json)
      else
        puts "GEMINI ERROR: #{response.body}"
        render json: { error: "AI was confused. Please speak clearer." }, status: 500
      end

    rescue StandardError => e
      render json: { error: e.message }, status: 500
    end
  end
end