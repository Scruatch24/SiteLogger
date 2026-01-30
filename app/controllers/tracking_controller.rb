class TrackingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :track ]

  ALLOWED_EVENTS = %w[recording_started recording_completed invoice_generated invoice_exported signup_completed].freeze

  def track
    event_name = params[:event_name]
    user_id = params[:user_id].presence
    session_id = params[:session_id].presence
    ip_address = request.remote_ip

    unless ALLOWED_EVENTS.include?(event_name)
      return render json: { status: "error", message: "Invalid event name" }, status: :bad_request
    end

    if limit_reached?(event_name, user_id, ip_address)
      return render json: { status: "error", message: "Rate limit reached" }, status: :too_many_requests
    end

    TrackingEvent.create!(
      event_name: event_name,
      user_id: user_id,
      session_id: session_id,
      ip_address: ip_address
    )

    render json: { status: "success" }, status: :ok
  rescue => e
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  end

  private

  def limit_reached?(event_name, user_id, ip_address)
    case event_name
    when "invoice_exported"
      check_export_limit(user_id, ip_address)
    when "recording_started"
      check_recording_limit(user_id, ip_address)
    else
      false
    end
  end

  def check_export_limit(user_id, ip_address)
    if user_id.blank?
      # Guest user: 2 per IP per minute
      count = TrackingEvent.where(event_name: "invoice_exported", ip_address: ip_address)
                          .where("created_at > ?", 1.minute.ago)
                          .count
      count >= 2
    else
      # Free user: 5 per user per day
      count = TrackingEvent.where(event_name: "invoice_exported", user_id: user_id)
                          .where("created_at > ?", 24.hours.ago)
                          .count
      count >= 5
    end
  end

  def check_recording_limit(user_id, ip_address)
    if user_id.blank?
      # Guest user: 2 per IP per minute
      count = TrackingEvent.where(event_name: "recording_started", ip_address: ip_address)
                          .where("created_at > ?", 1.minute.ago)
                          .count
      count >= 2
    else
      # Free user: 10 per user per minute
      count = TrackingEvent.where(event_name: "recording_started", user_id: user_id)
                          .where("created_at > ?", 1.minute.ago)
                          .count
      count >= 10
    end
  end
end
