class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_locale
  before_action :set_profile

  private

  def set_locale
    # Priority:
    # 1. Profile setting (saved preference)
    # 2. Session setting (guest preference)
    # 3. Auto-detection (IP-based)
    # 4. Global default (English)

    # If it's in the session but not a saved profile, we only keep it if it was manually set
    # Otherwise, we might want to re-detect if the IP changed (e.g. testing with VPN)
    if user_signed_in?
      @profile ||= current_user.profile || ensure_profile_exists!(current_user)
      requested_locale = @profile.try(:system_language).presence || session[:system_language]
    else
      requested_locale = session[:system_language]
    end

    if requested_locale.blank?
      requested_locale = auto_detect_locale
    end

    if I18n.available_locales.map(&:to_s).include?(requested_locale.to_s)
      I18n.locale = requested_locale.to_sym
    else
      I18n.locale = I18n.default_locale
    end

    # Sync session for guests
    session[:system_language] = I18n.locale.to_s
  end

  def auto_detect_locale
    return session[:auto_detected_locale] if session[:auto_detected_locale]

    country = detect_country_by_ip
    locale = (country == "GE") ? :ka : :en
    session[:auto_detected_locale] = locale.to_s
    locale
  rescue
    :en
  end

  def detect_country_by_ip
    ip = client_ip
    # Use nil for local/unknown to trigger default
    return nil if ip.blank? || ip == "127.0.0.1" || ip == "::1" || ip.start_with?("192.168.", "10.", "172.")

    begin
      require "net/http"
      require "json"
      uri = URI("http://ip-api.com/json/#{ip}?fields=countryCode")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 2
      http.open_timeout = 2
      response = http.request(Net::HTTP::Get.new(uri))
      JSON.parse(response.body)["countryCode"] if response.is_a?(Net::HTTPSuccess)
    rescue
      nil
    end
  end

  def set_profile
    if user_signed_in?
      @profile ||= current_user.profile || ensure_profile_exists!(current_user)
      # Upgrade legacy/inherited guest profiles to free for signed-in users
      if @profile.plan.blank? || @profile.plan == "guest"
        @profile.update_columns(plan: "free")
        @profile.reload
      end
    else
      @profile ||= Profile.new(
        business_name: I18n.t("guest_profile.business_name"),
        email: I18n.t("guest_profile.email"),
        phone: I18n.t("guest_profile.phone"),
        address: I18n.t("guest_profile.address"),
        hourly_rate: 100.00,
        tax_rate: 18.0,
        currency: "USD",
        tax_scope: "labor,materials_only",
        payment_instructions: I18n.t("guest_profile.payment_instructions"),
        note: I18n.t("guest_profile.note"),
        plan: "guest"
      )
    end
  end

  def ensure_profile_exists!(user)
    Profile.create!(
      user: user,
      business_name: "My Business",
      email: user.email,
      plan: "free",
      currency: "USD",
      hourly_rate: 100.00,
      tax_rate: 18.0,
      note: I18n.t("guest_profile.note"),
      billing_mode: "hourly",
      tax_scope: "labor,materials_only"
    )
  end

  # Get real client IP (handles Render.com reverse proxy)
  def client_ip
    request.env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip || request.remote_ip
  end
end
