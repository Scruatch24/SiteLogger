class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :enforce_single_session
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

    # Sync session for guests (always keep it up to date with I18n.locale)
    session[:system_language] = I18n.locale.to_s
  end

  def auto_detect_locale
    return session[:auto_detected_locale] if session[:auto_detected_locale]

    country = detect_country_by_ip
    locale = (country == "GE") ? :ka : :en
    session[:auto_detected_locale] = locale.to_s
    locale
  rescue StandardError => e
    Rails.logger.warn("auto_detect_locale failed: #{e.message}")
    :en
  end

  def detect_country_by_ip
    return session[:detected_country_code] if session[:detected_country_code].present?

    ip = client_ip
    return nil if ip.blank? || ip == "127.0.0.1" || ip == "::1" || ip.start_with?("192.168.", "10.", "172.")
    # SECURITY: Validate IP format to prevent SSRF via crafted X-Forwarded-For
    return nil unless ip.match?(/\A[\d.]+\z/) || ip.match?(/\A[0-9a-fA-F:]+\z/)

    # Try real IP lookup via ip-api.com (free, no key required)
    begin
      # Fields: 2 (status), 16384 (countryCode)
      response = HTTP.timeout(1.5).get("http://ip-api.com/json/#{CGI.escape(ip)}?fields=16386")
      if response.status.success?
        json = JSON.parse(response.body.to_s)
        if json["status"] == "success"
          country_code = json["countryCode"]
          session[:detected_country_code] = country_code
          return country_code
        end
      end
    rescue => e
      Rails.logger.warn("IP Geolocation failed for #{ip}: #{e.message}")
    end

    # Fallback to language header if IP lookup fails or is slow
    accept_lang = request.env["HTTP_ACCEPT_LANGUAGE"].to_s.downcase
    return "GE" if accept_lang.start_with?("ka")
    nil
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
        tax_scope: "labor,products_only",
        payment_instructions: I18n.t("guest_profile.payment_instructions"),
        note: I18n.t("guest_profile.note"),
        plan: "guest"
      )
    end
  end

  def ensure_profile_exists!(user)
    # Use Google display name if available, otherwise "My Business"
    biz_name = user.name.presence || "My Business"

    # Set note based on detected/selected system language
    locale = I18n.locale.to_s
    default_note = (locale == "ka") ? "მადლობა თანამშრომლობისთვის!" : "Thanks for your business!"

    Profile.create!(
      user: user,
      business_name: biz_name,
      email: user.email,
      plan: "free",
      currency: "USD",
      hourly_rate: 100.00,
      tax_rate: 18.0,
      note: default_note,
      billing_mode: "hourly",
      tax_scope: "labor,products_only",
      system_language: locale
    )
  end

  def enforce_single_session
    return unless user_signed_in?

    # Backfill: if user has no session_token yet, generate one for this session
    if current_user.session_token.blank?
      token = SecureRandom.hex(32)
      current_user.update_column(:session_token, token)
      session[:session_token] = token
      return
    end

    # If this session has no token (pre-existing session), adopt the current DB token
    if session[:session_token].blank?
      session[:session_token] = current_user.session_token
      return
    end

    # Mismatch means another device signed in — force sign out
    if session[:session_token] != current_user.session_token
      sign_out current_user
      flash[:alert] = I18n.t("devise.sessions.signed_out_other_device",
        default: "You were signed out because your account was signed in from another device.")
      redirect_to new_user_session_path and return
    end
  end

  # Get real client IP (handles Render.com reverse proxy)
  def client_ip
    request.env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip || request.remote_ip
  end
end
