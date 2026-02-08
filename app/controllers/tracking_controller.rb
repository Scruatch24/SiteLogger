class TrackingController < ApplicationController
  protect_from_forgery with: :null_session, only: [ :track ]

  ALLOWED_EVENTS = %w[recording_started recording_completed invoice_generated invoice_exported signup_completed].freeze

  def track
    event_name = params[:event_name]
    user_id = params[:user_id].to_s
    user_id = nil if user_id.blank? || user_id == "null"
    session_id = params[:session_id].presence
    target_id = params[:target_id].presence
    ip_address = client_ip
    Rails.logger.info "[TRACKING] Event=#{event_name}, IP=#{ip_address}"

    unless ALLOWED_EVENTS.include?(event_name)
      return render json: { status: "error", message: "Invalid event name" }, status: :bad_request
    end

    if limit_reached?(event_name, user_id, ip_address, target_id)
      return render json: { status: "error", message: "Rate limit reached" }, status: :too_many_requests
    end

    TrackingEvent.create!(
      event_name: event_name,
      user_id: user_id,
      session_id: session_id,
      ip_address: ip_address,
      target_id: target_id
    )

    render json: { status: "success" }, status: :ok
  rescue => e
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  end

  private

  def limit_reached?(event_name, user_id, ip_address, target_id = nil)
    case event_name
    when "invoice_exported"
      check_export_limit(user_id, ip_address, target_id)
    when "recording_started"
      check_recording_limit(user_id, ip_address)
    else
      false
    end
  end

  def check_export_limit(user_id, ip_address, target_id = nil)
    if user_id.blank?
      # Guest user limit
      limit = Profile::EXPORT_LIMITS["guest"] || 2

      # Count how many invoice_exported events they have in the last 24h
      count = TrackingEvent.where(event_name: "invoice_exported", ip_address: ip_address)
                          .where("created_at > ?", 24.hours.ago)
                          .count

      Rails.logger.info "[GUEST LIMIT CHECK] IP=#{ip_address}, Count=#{count}, Limit=#{limit}, Exceeded=#{count >= limit}"
      count >= limit
    else
      # Check user's plan tier
      user = User.find_by(id: user_id)
      return false unless user  # If user not found, allow

      profile = user.profile
      plan = profile&.plan || "free"
      limit = Profile::EXPORT_LIMITS[plan]

      # Paid users have unlimited exports (nil limit)
      return false if limit.nil?

      # Free users: X per account per day
      count = TrackingEvent.where(event_name: "invoice_exported", user_id: user_id)
                          .where("created_at > ?", 24.hours.ago)
                          .count
      count >= limit
    end
  end

  def check_recording_limit(user_id, ip_address)
    if user_id.blank?
      # Guest user: 2 per IP per minute
      count = TrackingEvent.where(event_name: "recording_started", ip_address: ip_address)
                          .where("created_at > ?", 1.minute.ago)
                          .count
      count >= 3
    else
      # Free user: 10 per user per minute
      count = TrackingEvent.where(event_name: "recording_started", user_id: user_id)
                          .where("created_at > ?", 1.minute.ago)
                          .count
      count >= 10
    end
  end
end
