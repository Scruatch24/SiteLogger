class Rack::Attack
  ### Configure Cache ###
  # Rack::Attack uses ActiveSupport::Cache.
  # Rails 8 uses solid_cache by default in production.
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.development?

  ### Throttle Spammy Clients ###

  # Throttle all requests to 10 requests per second per IP
  throttle("req/ip", limit: 10, period: 1.second) do |req|
    req.ip
  end

  ### AI Endpoint Protection ###
  # process_audio is the most expensive endpoint (Gemini API).
  # Limit to 3 requests per minute per IP.
  throttle("process_audio/ip", limit: 3, period: 1.minute) do |req|
    if req.path == "/process_audio" && req.post?
      req.ip
    end
  end

  ### Settings Save Protection ###
  # Limit to 10 requests per minute per IP.
  throttle("save_settings/ip", limit: 10, period: 1.minute) do |req|
    if (req.path == "/save_settings" || req.path == "/save_profile") && req.post?
      req.ip
    end
  end

  ### Custom Response ###
  self.throttled_responder = lambda do |env|
    [ 429,  # status
      { "Content-Type" => "application/json" },   # headers
      [ { error: "Rate limit exceeded. Please wait a moment." }.to_json ] # body
    ]
  end
end
