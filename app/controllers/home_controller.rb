class HomeController < ApplicationController
  helper :logs
  require "net/http"
  require "uri"
  require "json"
  require "base64"
  require "digest"
  require "cgi"
  require "csv"



  skip_before_action :enforce_single_session, only: :session_check

  def session_check
    if user_signed_in? && session[:session_token].present? && current_user.session_token.present? && session[:session_token] != current_user.session_token
      sign_out current_user
      render json: { valid: false }, status: :ok
    else
      render json: { valid: true }, status: :ok
    end
  end

  def complete_onboarding
    if user_signed_in? && @profile.persisted?
      @profile.update_columns(onboarded: true)
    end
    head :ok
  end

  def sitemap
    headers["Content-Type"] = "application/xml"
    render xml: <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url>
          <loc>https://talkinvoice.online/</loc>
          <changefreq>weekly</changefreq>
          <priority>1.0</priority>
        </url>
        <url>
          <loc>https://talkinvoice.online/users/sign_in</loc>
          <changefreq>monthly</changefreq>
          <priority>0.5</priority>
        </url>
        <url>
          <loc>https://talkinvoice.online/users/sign_up</loc>
          <changefreq>monthly</changefreq>
          <priority>0.6</priority>
        </url>
      </urlset>
    XML
  end

  def pricing
  end

  def analytics
    @is_pro  = user_signed_in? && current_user.profile&.paid?
    @is_demo = !@is_pro

    if @is_demo
      populate_analytics_demo_data
      return
    end

    user_id = current_user.id
    profile = @profile || current_user.profile || Profile.new
    logs = current_user.logs.kept
    today = Date.today

    # ── Single-pass invoice analytics (cached) ──
    analytics_ttl = (ENV["ANALYTICS_CACHE_TTL"].to_i.positive? ? ENV["ANALYTICS_CACHE_TTL"].to_i : 600).seconds
    cache_key = "analytics/v3/#{user_id}/#{logs.maximum(:updated_at).to_i}"
    analytics_data = Rails.cache.fetch(cache_key, expires_in: analytics_ttl) do
      compute_invoice_analytics(current_user, profile, today)
    end

    @total_invoiced       = analytics_data[:total_invoiced]
    @total_outstanding    = analytics_data[:total_outstanding]
    @total_overdue_amt    = analytics_data[:total_overdue_amount]
    @total_paid_amt       = analytics_data[:total_paid_amount]
    @collected_this_month = analytics_data[:collected_this_month]
    @status_counts        = analytics_data[:status_counts]
    @aging                = analytics_data[:aging]
    @aging_invoices       = analytics_data[:aging_invoices] || {}
    @aging_amounts        = analytics_data[:aging_amounts] || {}
    @due_today_count      = analytics_data[:due_today_count]
    @due_soon_count       = analytics_data[:due_soon_count]
    @due_soon_amount      = analytics_data[:due_soon_amount]
    @overdue_count        = analytics_data[:overdue_count]
    @client_insights      = analytics_data[:client_insights]
    @repeat_clients       = analytics_data[:repeat_clients]
    @new_clients_month    = analytics_data[:new_clients_month]
    @avg_invoice          = analytics_data[:avg_invoice]
    @health_score         = analytics_data[:health_score]
    @health_level         = analytics_data[:health_level]
    @collection_rate      = analytics_data[:collection_rate]
    @outstanding_ratio    = analytics_data[:outstanding_ratio]
    @projected_revenue    = analytics_data[:projected_revenue]
    @revenue_trend        = analytics_data[:revenue_trend]
    @invoices_trend       = analytics_data[:invoices_trend]
    @new_clients_trend    = analytics_data[:new_clients_trend]
    @avg_days_to_pay      = analytics_data[:avg_days_to_pay]
    @due_soon_invoices    = analytics_data[:due_soon_invoices] || []
    @top_client_share     = analytics_data[:top_client_share]
    @top_client_name      = analytics_data[:top_client_name]
    @outstanding_trend    = analytics_data[:outstanding_trend]

    # ── Cache timestamp for "Last updated" display ──
    @analytics_cached_at = analytics_data[:cached_at]

    # ── Currency for charts ──
    @currency_symbol = case (profile.currency.presence || "USD")
                       when "GEL" then "₾"
                       when "EUR" then "€"
                       when "GBP" then "£"
                       else "$"
                       end

    # ── Alerts ──
    @alerts = build_alerts(analytics_data, profile)

    # ── Lightweight counts from overview/tracking ──
    @overview = AnalyticsEvent.overview_for(user_id)

    @tracking_counts = {
      exports: TrackingEvent.where(event_name: "invoice_exported", user_id: user_id).count,
      recordings_started: TrackingEvent.where(event_name: "recording_started", user_id: user_id).count
    }
  end

  def analytics_data
    unless user_signed_in?
      return render json: { error: "unauthorized" }, status: :unauthorized
    end

    period = params[:period].presence || "30d"
    metric = params[:metric].presence || "invoices"

    case metric
    when "outstanding"
      # Outstanding amount time-series from logs
      data = outstanding_time_series(current_user.id, period)
      filled = fill_time_series(data, period)
      render json: { labels: filled.keys, values: filled.values, period: period, metric: metric }
    when "collected"
      # Collected (paid) invoices time-series
      data = collected_time_series(current_user.id, period)
      filled = fill_time_series(data, period)
      render json: { labels: filled.keys, values: filled.values, period: period, metric: metric }
    else
      # Original metrics: invoices, voice, revenue
      data = AnalyticsEvent.time_series_for(current_user.id, period: period, metric: metric)
      filled = fill_time_series(data, period)
      render json: { labels: filled.keys, values: filled.values, period: period, metric: metric }
    end
  end

  def analytics_export
    unless user_signed_in?
      redirect_to root_path and return
    end

    profile = @profile || current_user.profile || Profile.new
    locale = profile.system_language.presence || I18n.locale
    today = Date.today

    I18n.with_locale(locale) do
      data = compute_invoice_analytics(current_user, profile, today)
      currency_code = profile.currency.presence || "USD"
      currency_sym = currency_symbol_for(currency_code)

      # ── Build per-invoice rows ──
      invoice_rows = []
      current_user.logs.kept.find_each do |log|
        totals = helpers.calculate_log_totals(log, profile)
        amount = totals[:total_due].to_f.round(2)
        effective_status = log.current_status
        parsed_due = log.parsed_due_date
        days_to_pay = nil
        aging_cat = "—"

        if effective_status == "paid" && log.paid_at && log.created_at
          days_to_pay = ((log.paid_at - log.created_at) / 1.day).round(1)
        end

        if parsed_due
          days_diff = (today - parsed_due).to_i
          aging_cat = if effective_status == "paid"
                        t("analytics_export.aging_paid")
                      elsif days_diff < 0
                        t("analytics_export.aging_not_due")
                      elsif days_diff == 0
                        t("analytics_export.aging_due_today")
                      elsif days_diff <= 7
                        t("analytics_export.aging_1_7")
                      elsif days_diff <= 30
                        t("analytics_export.aging_7_30")
                      else
                        t("analytics_export.aging_30_plus")
                      end
        end

        invoice_rows << {
          id: "INV-#{log.display_number}",
          client: log.client.to_s.strip.presence || t("unknown_client"),
          status: t("analytics_export.status_#{effective_status}", default: effective_status.capitalize),
          amount: amount,
          currency: currency_code,
          due_date: parsed_due&.strftime("%Y-%m-%d") || "—",
          paid_date: log.paid_at&.strftime("%Y-%m-%d") || "—",
          days_to_pay: days_to_pay || "—",
          aging: aging_cat
        }
      end

      csv_data = CSV.generate(encoding: "UTF-8") do |csv|
        # ── Section 1: Invoice Summary ──
        csv << [t("analytics_export.section_invoices")]
        csv << [
          t("analytics_export.col_invoice_id"),
          t("analytics_export.col_client"),
          t("analytics_export.col_status"),
          t("analytics_export.col_amount"),
          t("analytics_export.col_currency"),
          t("analytics_export.col_due_date"),
          t("analytics_export.col_paid_date"),
          t("analytics_export.col_days_to_pay"),
          t("analytics_export.col_aging")
        ]
        invoice_rows.each do |row|
          csv << [row[:id], row[:client], row[:status], row[:amount], row[:currency], row[:due_date], row[:paid_date], row[:days_to_pay], row[:aging]]
        end
        csv << []

        # ── Section 2: Financial Metrics ──
        csv << [t("analytics_export.section_metrics")]
        csv << [t("analytics_export.col_metric"), t("analytics_export.col_value"), t("analytics_export.col_notes")]
        metrics = [
          [t("analytics_export.metric_total_invoices"), data[:status_counts].values.sum, ""],
          [t("analytics_export.metric_total_paid"), "#{currency_sym}#{data[:total_paid_amount]}", ""],
          [t("analytics_export.metric_total_outstanding"), "#{currency_sym}#{data[:total_outstanding]}", ""],
          [t("analytics_export.metric_overdue_count"), data[:overdue_count], ""],
          [t("analytics_export.metric_collection_rate"), "#{data[:collection_rate]}%", ""],
          [t("analytics_export.metric_projected_revenue"), "#{currency_sym}#{data[:projected_revenue]}", t("analytics_export.note_this_month")],
          [t("analytics_export.metric_avg_invoice"), "#{currency_sym}#{data[:avg_invoice]}", ""],
          [t("analytics_export.metric_avg_days_to_pay"), data[:avg_days_to_pay] || "—", ""],
          [t("analytics_export.metric_health_score"), "#{data[:health_score]}%", data[:health_level]],
          [t("analytics_export.metric_collected_this_month"), "#{currency_sym}#{data[:collected_this_month]}", ""],
          [t("analytics_export.metric_total_invoiced"), "#{currency_sym}#{data[:total_invoiced]}", ""]
        ]
        metrics.each { |m| csv << m }
        csv << []

        # ── Section 3: Client Insights ──
        csv << [t("analytics_export.section_clients")]
        csv << [
          t("analytics_export.col_client"),
          t("analytics_export.col_total_invoiced"),
          t("analytics_export.col_outstanding"),
          t("analytics_export.col_repeat_client"),
          t("analytics_export.col_last_invoice_date"),
          t("analytics_export.col_top_client")
        ]
        data[:client_insights].each do |client|
          repeat = client[:count] > 1 ? t("analytics_export.yes") : t("analytics_export.no")
          top = client[:badges].include?("top_client") ? t("analytics_export.yes") : t("analytics_export.no")
          csv << [
            client[:name],
            "#{currency_sym}#{client[:total]}",
            "#{currency_sym}#{client[:outstanding]}",
            repeat,
            client[:last_at]&.strftime("%Y-%m-%d") || "—",
            top
          ]
        end
      end

      bom = "\xEF\xBB\xBF"
      send_data bom + csv_data, filename: "analytics_#{today.strftime('%Y-%m-%d')}.csv", type: "text/csv; charset=utf-8", disposition: "attachment"
    end
  end

  def analytics_export_pdf
    unless user_signed_in?
      redirect_to root_path and return
    end

    profile = @profile || current_user.profile || Profile.new
    locale = profile.system_language.presence || I18n.locale
    today = Date.today

    I18n.with_locale(locale) do
      data = compute_invoice_analytics(current_user, profile, today)
      alerts = build_alerts(data, profile)
      currency_code = profile.currency.presence || "USD"
      currency_sym = currency_symbol_for(currency_code)

      # Build invoice rows for PDF
      invoice_rows = []
      current_user.logs.kept.find_each do |log|
        totals = helpers.calculate_log_totals(log, profile)
        amount = totals[:total_due].to_f.round(2)
        effective_status = log.current_status
        parsed_due = log.parsed_due_date
        days_to_pay = nil
        aging_cat = "—"

        if effective_status == "paid" && log.paid_at && log.created_at
          days_to_pay = ((log.paid_at - log.created_at) / 1.day).round(1)
        end

        if parsed_due
          days_diff = (today - parsed_due).to_i
          aging_cat = if effective_status == "paid"
                        t("analytics_export.aging_paid")
                      elsif days_diff < 0
                        t("analytics_export.aging_not_due")
                      elsif days_diff == 0
                        t("analytics_export.aging_due_today")
                      elsif days_diff <= 7
                        t("analytics_export.aging_1_7")
                      elsif days_diff <= 30
                        t("analytics_export.aging_7_30")
                      else
                        t("analytics_export.aging_30_plus")
                      end
        end

        invoice_rows << {
          id: "INV-#{log.display_number}",
          client: log.client.to_s.strip.presence || t("unknown_client"),
          status: effective_status,
          status_label: t("analytics_export.status_#{effective_status}", default: effective_status.capitalize),
          amount: amount,
          currency: currency_code,
          due_date: parsed_due&.strftime("%Y-%m-%d") || "—",
          paid_date: log.paid_at&.strftime("%Y-%m-%d") || "—",
          days_to_pay: days_to_pay || "—",
          aging: aging_cat
        }
      end

      pdf_data = AnalyticsPdfGenerator.new(
        data: data,
        alerts: alerts,
        invoice_rows: invoice_rows,
        client_insights: data[:client_insights],
        currency_sym: currency_sym,
        currency_code: currency_code,
        today: today,
        profile: profile,
        locale: locale
      ).render

      send_data pdf_data, filename: "analytics_#{today.strftime('%Y-%m-%d')}.pdf", type: "application/pdf", disposition: "attachment"
    end
  end

  def subscription
    unless user_signed_in? && current_user.profile&.ever_paid?
      redirect_to pricing_path and return
    end

    # Clear stale cache so payment method updates are reflected immediately
    Rails.cache.delete(subscription_billing_cache_key(current_user.profile))
    load_subscription_billing_data(current_user.profile)
  end

  def create_billing_portal
    profile = current_user&.profile

    unless user_signed_in? && profile&.ever_paid?
      redirect_to pricing_path and return
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    if api_key.blank?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable") and return
    end

    customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
    resolved_customer_id = customer_id

    if customer_id.blank?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_customer_missing") and return
    end

    portal_result = paddle_customer_portal_url(api_key: api_key, customer_id: resolved_customer_id)
    Rails.logger.info("BILLING PORTAL: customer_id=#{resolved_customer_id} result_class=#{portal_result.class} result=#{portal_result.to_s[0..80]}")
    if portal_result == :customer_missing
      if profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.present?
        profile.update_columns(paddle_customer_id: nil)
      end

      refreshed_customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
      if refreshed_customer_id.present?
        resolved_customer_id = refreshed_customer_id
        portal_result = paddle_customer_portal_url(api_key: api_key, customer_id: resolved_customer_id)
      end
    end

    if portal_result == :forbidden
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_permissions") and return
    end

    unless portal_result.is_a?(String) && portal_result.present?
      redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable") and return
    end

    if profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.blank? && resolved_customer_id.present?
      profile.update_columns(paddle_customer_id: resolved_customer_id)
    end

    # Refresh subscription_id from latest transactions so portal links target the correct subscription
    refresh_latest_subscription_id(profile: profile, api_key: api_key, customer_id: resolved_customer_id)

    final_url = portal_deep_link(overview_url: portal_result, action: params[:portal_action].to_s, profile: profile)
    redirect_to final_url, allow_other_host: true
  rescue => e
    Rails.logger.warn("PADDLE BILLING PORTAL ERROR: #{e.message}")
    redirect_to subscription_path, alert: t("subscription_page.billing_portal_unavailable")
  end

  def contact
  end

  def send_contact
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    description = params[:description].to_s.strip

    if email.blank? || subject.blank? || description.blank?
      flash[:alert] = t("contact_page.validation_error")
      redirect_to contact_path and return
    end

    begin
      ContactMailer.notify_admin(email: email, subject: subject, description: description).deliver_later
      ContactMailer.confirm_user(email: email, locale: I18n.locale).deliver_later
      flash[:notice] = t("contact_page.success")
    rescue => e
      Rails.logger.error("Contact form error: #{e.message}")
      flash[:notice] = t("contact_page.success")
    end

    redirect_to contact_path
  end

  def terms
  end

  def privacy
  end

  def refund
  end

  def checkout
    if user_signed_in? && current_user.profile&.paid?
      redirect_to subscription_path, notice: t("checkout_page.already_pro") and return
    end
  end

  def confirm_checkout
    unless user_signed_in?
      return render json: { success: false, error: "unauthorized" }, status: :unauthorized
    end

    transaction_id = params[:transaction_id].to_s.strip
    if transaction_id.blank?
      return render json: { success: false, error: "missing_transaction_id" }, status: :unprocessable_entity
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    if api_key.blank?
      return render json: { success: false, error: "paddle_api_key_missing" }, status: :unprocessable_entity
    end

    transaction = paddle_transaction_details(api_key: api_key, transaction_id: transaction_id)
    if transaction == :forbidden
      Rails.logger.warn("PADDLE CHECKOUT CONFIRM: Paddle API unauthorized. Check PADDLE_API_KEY permissions/environment.")
      return render json: { success: false, error: "paddle_api_unauthorized", retryable: false }, status: :unprocessable_entity
    end

    if transaction.blank?
      Rails.logger.info("PADDLE CHECKOUT CONFIRM: transaction not found yet (transaction_id=#{transaction_id})")
      return render json: { success: false, error: "transaction_not_found", retryable: true }, status: :accepted
    end

    status = transaction["status"].to_s.downcase
    unless [ "paid", "completed", "billed" ].include?(status)
      retryable = [ "ready", "draft", "pending", "processing" ].include?(status)
      Rails.logger.info("PADDLE CHECKOUT CONFIRM: not paid yet (transaction_id=#{transaction_id}, status=#{status}, retryable=#{retryable})")
      return render json: { success: false, error: "transaction_not_paid", status: status, retryable: retryable }, status: (retryable ? :accepted : :unprocessable_entity)
    end

    customer_id = transaction["customer_id"].presence || transaction.dig("customer", "id")
    customer_email = transaction.dig("customer", "email").presence ||
      transaction["customer_email"].presence
    custom_data_user_id = transaction.dig("custom_data", "user_id").to_s
    subscription_id = transaction["subscription_id"]
    item = (transaction["items"] || []).first || {}
    price_id = item["price_id"].presence || item.dig("price", "id")

    profile = current_user.profile
    owned_by_current_user =
      custom_data_user_id == current_user.id.to_s ||
      customer_email.to_s.casecmp(current_user.email.to_s).zero? ||
      (profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.to_s == customer_id.to_s)

    unless owned_by_current_user
      Rails.logger.warn("PADDLE CHECKOUT CONFIRM: user mismatch (transaction_id=#{transaction_id}, user_id=#{current_user.id})")
      return render json: { success: false, error: "transaction_user_mismatch" }, status: :forbidden
    end

    update_attrs = {
      plan: "paid",
      paddle_price_id: price_id,
      paddle_customer_email: (customer_email.presence || current_user.email),
      paddle_subscription_status: "active"
    }
    if profile.respond_to?(:paddle_customer_id) && customer_id.present?
      update_attrs[:paddle_customer_id] = customer_id
    end
    update_attrs[:paddle_subscription_id] = subscription_id if subscription_id.present?

    profile.update_columns(update_attrs)
    Rails.logger.info("PADDLE CHECKOUT CONFIRM: upgraded profile_id=#{profile.id} transaction_id=#{transaction_id}")
    render json: { success: true }
  rescue => e
    Rails.logger.warn("PADDLE CHECKOUT CONFIRM ERROR: #{e.message}")
    render json: { success: false, error: "checkout_confirm_failed" }, status: :unprocessable_entity
  end

  def index
    @categories = if user_signed_in?
      # Ensure Favorites category exists and has correct styling (Self-Healing)
      fav = current_user.categories.where("name ILIKE ?", "Favorites").first_or_initialize
      if fav.new_record? || fav.name != "Favorites" || fav.color != "#EAB308" || fav.icon != "star"
        fav.update(name: "Favorites", color: "#EAB308", icon: "star", icon_type: "premade")
      end

      current_user.categories.order(name: :asc)
    else
      []
    end
  end

  def history
    @logs = if user_signed_in?
      current_user.logs.kept.eager_load(:categories).order(Arel.sql("CASE WHEN logs.pinned = true THEN 0 ELSE 1 END, logs.pinned_at ASC NULLS LAST, logs.invoice_number DESC NULLS LAST"))
    else
      # Guest history is private to the IP adress - return empty as requested
      []
    end

    @categories = if user_signed_in?
      # Ensure Favorites category exists and has correct styling (Self-Healing)
      fav = current_user.categories.where("name ILIKE ?", "Favorites").first_or_initialize
      if fav.new_record? || fav.name != "Favorites" || fav.color != "#EAB308" || fav.icon != "star"
        fav.update(name: "Favorites", color: "#EAB308", icon: "star", icon_type: "premade")
      end

      current_user.categories.preload(:log_category_assignments, logs: :log_category_assignments).order(name: :asc)
    else
      []
    end

    @clients = if user_signed_in?
      current_user.clients.ordered.includes(:logs)
    else
      []
    end
  end

  def settings
    # @profile is already set by the before_action
    # Guests can view but fields are disabled in the view
  end

  def disconnect_google
    unless user_signed_in?
      return render json: { success: false, error: "Not authenticated" }, status: :unauthorized
    end

    user = current_user

    # Only allow disconnect if user originally signed up via email (not Google-only).
    # Email users have confirmation_sent_at set; Google-only users have skip_confirmation! which skips it.
    unless user.confirmation_sent_at.present?
      return render json: { success: false, error: t("google_disconnect_needs_password") }, status: :unprocessable_entity
    end

    user.update_columns(provider: nil, uid: nil)
    render json: { success: true }
  end

  def profile
    @is_new_profile = !@profile.persisted?
    # Guests can view but fields are disabled in the view
  end

  def save_profile
    if @profile.guest?
      return render json: { success: false, errors: [ t('guests_cannot_save') ] }, status: :forbidden
    end

    # Strip logo from params if free user tries to upload
    filtered = profile_params
    unless @profile.paid?
      filtered = filtered.except(:logo)
    end

    @profile.assign_attributes(filtered)

    respond_to do |format|
      if @profile.save
        format.html { redirect_to profile_path, notice: t("profile_saved") }
        format.json { render json: { success: true, message: t("profile_saved") } }
      else
        format.html { render :profile, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def set_session_locale
    locale = params[:locale].to_s
    if I18n.available_locales.map(&:to_s).include?(locale)
      session[:system_language] = locale
      session[:locale_explicitly_set] = true

      if user_signed_in? && @profile.persisted?
        @profile.update_columns(system_language: locale)
      end
    end

    head :ok
  end

  def set_transcript_language
    lang = params[:language].to_s
    if %w[en ge ka].include?(lang)
      db_lang = (lang == "ge") ? "ka" : lang
      session[:transcription_language] = db_lang

      if user_signed_in? && @profile.persisted?
        @profile.update_columns(transcription_language: db_lang)
      end
    end

    head :ok
  end

  def enhance_transcript_text
    api_key = ENV["GEMINI_API_KEY"]
    limit = @profile.char_limit
    enhancement_limit = @profile.enhancement_limit
    raw_text = params[:manual_text].to_s.strip

    if raw_text.blank?
      return render json: { error: t("input_empty", default: "Input empty") }, status: :unprocessable_entity
    end

    if raw_text.length > limit
      return render json: { error: "#{t('transcript_limit_exceeded')} (#{limit})." }, status: :unprocessable_entity
    end

    if enhancement_limit.present?
      usage_scope = UsageEvent.where(event_type: "text_enhancement")
                              .where("created_at >= ?", Time.current.beginning_of_day)

      usage_scope = if user_signed_in?
        usage_scope.where(user_id: current_user.id)
      else
        usage_scope.where(user_id: nil, ip_address: client_ip)
      end

      if usage_scope.count >= enhancement_limit
        return render json: {
          error: t("daily_limit_reached", limit: enhancement_limit)
        }, status: :too_many_requests
      end
    end

    doc_language = (params[:language] || @profile.try(:transcription_language) || session[:transcription_language] || @profile.try(:document_language) || "en").to_s.downcase
    target_language_name = case doc_language
    when "ge", "ka"
      "Georgian"
    when "en"
      "English"
    else
      "the language identified by ISO code '#{doc_language}'"
    end
    output_language_rule = "Return output only in #{target_language_name}."

    instruction = <<~TEXT
      You clean up speech-to-text transcripts for invoice extraction. Be MINIMAL and CONSERVATIVE.

      GOLDEN RULE: If the text is already clear and well-structured, return it UNCHANGED or with only trivial fixes (typos, punctuation). Do NOT rewrite text that an AI can already parse correctly.

      ONLY fix these problems when present:
      1. Speech artifacts: "uh", "um", "like", "basically", "ანუ", "ეგ", "ხო", repeated words/phrases
      2. Broken sentences from speech recognition (missing punctuation, run-on text)
      3. Obvious typos and misspellings
      4. If text is a messy stream-of-consciousness, add line breaks between distinct items
      5. Space-separated thousands in prices: "4 599" → "4599", "12 000" → "12000", "1 200 000" → "1200000". These are common in Georgian speech and cause parsing errors. Collapse them into single numbers.

      NEVER do these:
      - NEVER rewrite, rephrase, or restructure already-clear sentences
      - NEVER combine quantities with unit prices (keep "3 servers at 8,500 each" as-is, NOT "servers 25,500")
      - NEVER change, round, or recalculate any numbers
      - NEVER add information, labels, or formatting not in the original
      - NEVER make tax/discount instructions vaguer than the original
      - NEVER remove meaningful words or change meaning

      LANGUAGE:
      - If USER TEXT is not in #{target_language_name}, translate it to #{target_language_name}.
      - If USER TEXT is already in #{target_language_name}, keep the same language.
      - #{output_language_rule}

      OUTPUT: Return ONLY the cleaned text. No JSON, no markdown, no quotes, no commentary.
      Maximum #{limit} characters.

      USER TEXT:
      #{raw_text}
    TEXT

    gemini_model = ENV["GEMINI_PRIMARY_MODEL"].presence || "gemini-2.5-flash-lite"

    body = gemini_generate_content(
      api_key: api_key,
      model: gemini_model,
      prompt_parts: [ { text: instruction } ],
      cached_instruction_name: nil
    )

    if body["error"].present?
      Rails.logger.warn("ENHANCE MODEL ERROR (#{gemini_model}): #{body["error"].to_json}")
      return render json: { error: t("ai_failed_response") }, status: 500
    end

    parts = body.dig("candidates", 0, "content", "parts")
    enhanced_text = parts&.reject { |p| p["thought"] }&.map { |p| p["text"] }&.join(" ")&.to_s&.strip

    if enhanced_text.present?
      enhanced_text = enhanced_text.gsub(/\A```(?:text)?\s*/i, "").gsub(/\s*```\z/, "").strip
      enhanced_text = enhanced_text.gsub(/\A["""']+|["""']+\z/, "").strip
    end

    if enhanced_text.blank?
      return render json: { error: t("ai_failed_response") }, status: 500
    end

    enhanced_text = enhanced_text[0, limit]

    # Conservative guardrail: reject only when a classifier is highly confident
    # the enhanced transcript is incoherent or unrelated to invoice extraction.
    begin
      validator_prompt = <<~TEXT
        You validate whether transcript text is usable for invoice JSON extraction.
        Return invoice_related=false ONLY when the text is clearly gibberish/incoherent
        OR clearly unrelated to invoicing/billing/work log/services/products/expenses.
        If uncertain, return true.

        Return STRICT JSON only:
        {"invoice_related": true/false, "confidence": 0.0-1.0}

        TEXT:
        #{enhanced_text}
      TEXT

      validation_model = gemini_model
      validation_body = gemini_generate_content(
        api_key: api_key,
        model: validation_model,
        prompt_parts: [ { text: validator_prompt } ],
        cached_instruction_name: nil
      )

      validation_parts = validation_body.dig("candidates", 0, "content", "parts")
      validation_raw = validation_parts&.reject { |p| p["thought"] }&.map { |p| p["text"] }&.join(" ")&.to_s&.strip

      if validation_raw.present?
        validation_json = validation_raw[/\{.*\}/m]
        if validation_json.present?
          parsed = JSON.parse(validation_json) rescue nil
          invoice_related = parsed.is_a?(Hash) ? parsed["invoice_related"] : nil
          confidence = parsed.is_a?(Hash) ? parsed["confidence"].to_f : 0.0

          if invoice_related == false && confidence >= 0.8
            return render json: { error: t("input_unclear") }, status: :unprocessable_entity
          end
        end
      end
    rescue => e
      Rails.logger.warn("ENHANCE VALIDATION SKIPPED: #{e.message}")
    end

    begin
      UsageEvent.create!(
        user_id: current_user&.id,
        ip_address: client_ip,
        session_id: session.id.to_s,
        event_type: "text_enhancement"
      )
    rescue => e
      Rails.logger.warn("ENHANCE USAGE LOGGING FAILED: #{e.message}")
    end

    render json: { enhanced_text: enhanced_text }
  rescue => e
    Rails.logger.error("ENHANCE TRANSCRIPT ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: t("processing_error") }, status: 500
  end

  def save_settings
    if @profile.guest?
      return render json: { success: false, errors: [ t('guests_cannot_save') ] }, status: :forbidden
    end

    # We use the @profile set by before_action
    @profile.assign_attributes(profile_params)

    # Force classic style and orange accent for free users
    unless @profile.paid?
      @profile.invoice_style = "classic"
      @profile.accent_color = "#F97316"
    end

    respond_to do |format|
      if @profile.save
        session[:locale_explicitly_set] = true
        format.html { redirect_to settings_path, notice: t("profile_saved") }
        format.json { render json: { success: true, message: t("profile_saved") } }
      else
        format.html { render :settings, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @profile.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def process_audio
    @_analytics_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    api_key = ENV["GEMINI_API_KEY"]
    has_audio = params[:audio].present?
    is_manual_text = !has_audio && params[:manual_text].present?
    mode = @profile.billing_mode || "hourly"
    limit = @profile.char_limit

    # Server-side Audio Duration Check
    if has_audio && params[:audio_duration].present? && params[:audio_duration].to_f < 1.0
       return render json: { error: t("audio_too_short") }, status: :unprocessable_entity
    end

    # Empty/barely legible input check
    if is_manual_text && params[:manual_text].to_s.strip.length < 2
      return render json: { error: t("input_too_short", default: "Input too short to process.") }, status: :unprocessable_entity
    end

    # Character Limit Check
    current_length = params[:manual_text].to_s.length
    # We allow a 250-character buffer on the server to account for the overhead
    # of [User clarification...] tags added during refinements.
    # The frontend strictly enforces the raw user limit of #{limit}.
    if is_manual_text && current_length > (limit + 250)
      return render json: {
        error: "#{t('transcript_limit_exceeded')} (#{limit + 250})."
      }, status: :unprocessable_entity
    end

    # Transcribe-only mode for clarification answers (quick transcription without full processing)
    if params[:transcribe_only].present? && params[:audio].present?
      begin
        audio = params[:audio]
        audio_data = Base64.strict_encode64(audio.read)

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15
        http.open_timeout = 5

        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
        req.body = {
          contents: [ {
            parts: [
              { text: "Transcribe this short audio clip. Return ONLY the spoken text, nothing else. If the audio is silent, empty, contains only noise/breathing, or has no intelligible speech, return exactly the word EMPTY and nothing else. Do NOT invent or hallucinate any words." },
              { inline_data: { mime_type: audio.content_type, data: audio_data } }
            ]
          } ]
        }.to_json

        res = http.request(req)
        body = JSON.parse(res.body) rescue {}

        parts = body.dig("candidates", 0, "content", "parts")
        raw = parts&.reject { |p| p["thought"] }&.map { |p| p["text"] }&.join(" ")&.strip

        if raw.blank? || raw.strip.upcase == "EMPTY" || raw.strip.length < 2
          return render json: { raw_summary: "" }
        end

        return render json: { raw_summary: raw }
      rescue => e
        Rails.logger.error "TRANCRIPTION ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
        return render json: { error: t("transcription_failed") }, status: 500
      end
    end

    # Priority: 1. URL Param, 2. Profile Transcription Lang, 3. session, 4. Profile Doc Lang, 5. Default English
    # NOTE: AI language should not be affected by UI/system language
    doc_language = params[:language] || @profile.try(:transcription_language) || session[:transcription_language] || @profile.try(:document_language) || "en"
    target_is_georgian = (doc_language == "ge" || doc_language == "ka")

    lang_context = if target_is_georgian
      "████ TARGET LANGUAGE: GEORGIAN (ქართული) ████ ALL text content in the output JSON MUST be in Georgian. This applies to: \"desc\", \"name\", \"reason\", \"raw_summary\", \"sub_categories\" text, and \"client\". JSON field NAMES and section keys (\"labor\", \"materials\", etc.) stay in English — only VALUES are Georgian. WARNING: The examples in this prompt are in English for readability; you MUST output Georgian text regardless. E.g., 'Filter Replacement' → 'ფილტრის შეცვლა', 'Nails' → 'ლურსმნები', 'AC Repair' → 'კონდიციონერის შეკეთება'. If user input is already Georgian, keep it Georgian. If user input is English, translate values to Georgian."
    else
      "TARGET LANGUAGE: English. All extracted names, descriptions, and sub_categories text MUST be in English. If the input is in Georgian or any other language, you MUST translate ALL text content to English. Do NOT leave any Georgian text in item names or descriptions. E.g., 'ნაჯახი' becomes 'Axe', 'მაცივრის შეკეთება' becomes 'Refrigerator Repair', 'ფანჯრის შეკეთება' becomes 'Window Repair', 'ლურსმანი' becomes 'Nail'."
    end

    # Section Labels for the generated JSON
    # IMPORTANT: Section titles should match the SYSTEM LANGUAGE (UI), NOT the Transcript Language
    # The Transcript Language only affects item names/descriptions, not category titles
    ui_is_georgian = (I18n.locale.to_s == "ka")
    sec_labels = if ui_is_georgian
      { labor: "პროფესიონალური მომსახურება", materials: "მასალები/პროდუქტები", expenses: "ხარჯები", fees: "მოსაკრებლები" }
    else
      { labor: "Labor/Service", materials: "Materials/Products", expenses: "Expenses", fees: "Fees" }
    end

    hours_per_workday = (@profile.hours_per_workday.presence || 8).to_f
    hours_per_workday = hours_per_workday.to_i if (hours_per_workday % 1).zero?
    three_days_hours = hours_per_workday * 3
    half_day_hours = hours_per_workday / 2.0
    today_for_prompt = Date.today.strftime("%b %d, %Y")

    begin
      instruction = <<~PROMPT
        #{lang_context}
        You are a STRICT data extractor for casual contractors (plumbers, electricians, techs).
Your job: convert spoken notes or written text into a single valid JSON invoice object. Be robust to slang and casual phrasing, but never invent financial values or change accounting semantics.

AUDIO RECONCILIATION RULE:
- If both audio and a "BROWSER LIVE TRANSCRIPT" text block are provided, use the AUDIO as the primary source of truth and treat browser text as a noisy hint.
- Reconcile phrase-by-phrase and keep whichever wording is more accurate from either source.
- The "raw_summary" field MUST contain the final reconciled transcript text.

----------------------------
CORE DIRECTIVES (non-negotiable)
----------------------------
1. DO NOT invent data. Only extract facts explicitly stated. Use null for unknown or ambiguous fields instead of erroring, unless the entire input is unrelated to billing or a job. (EXCEPTION: For "clarifications" array, you MAY guess a reasonable placeholder value.)
2. DO NOT calculate totals. Return raw values (hours, rates, item prices). No multiplication or derived totals.
3. If user states a specific rate/price it overrides defaults. Provided values ALWAYS take priority.
4. Respect strict accounting rule: ANY reduction spoken/written as occurring "after tax", "off the total", "from the final bill", "at the end", "off the invoice" must be treated as a CREDIT (credit_flat), NOT a discount (global or otherwise). Item prices and taxes must remain unchanged in this case.
5. TAXABILITY: Return `taxable: null` (literal null) for all items unless the user EXPLICITLY says "tax free", "no tax", "exempt", or "add tax". Do NOT infer taxability yourself; allow the system default (based on tax scope) to apply.
6. GROUPS & BUNDLING: If a total price is given for a category (e.g. "Materials were 2300" or "Labor was 1200"), you MUST create ONE priced item for that category.
   - Example Input: "Condenser, coil, line set... materials were 2300"
   - Output: ONE Materials item { "name": "Materials", "qty": 1, "unit_price": 2300, "sub_categories": ["Condenser", "Coil", "Line set"], "taxable": null }.
   - LATE TOTAL RULE: Even if items are listed first without prices (e.g. "Got a condenser and a coil... total materials 2300"), consolidate them into a single item with the total price. Do NOT leave them priced at 0.
7. NUMERIC WORDS: "twelve hundred" -> 1200, "twenty-three hundred" -> 2300, "thirty-five hundred" -> 3500. Always return numbers as numeric strings or integers.
8. CLIENT EXTRACTION: Explicitly look for introductions like "This is [Name]", "Invoice for [Name]", "Bill to [Name]".
   - "Hello, this is Apex Roofing" -> Client: "Apex Roofing"
   - Georgian: "კლიენტი", "კლიენტია" → extract the name that follows.
   - GEORGIAN COMPANY NAMES: In Georgian, the legal form (შპს, სს, შპს-ი) comes BEFORE the quoted company name. Normalize: "ჯეო ლოჯისტიქსი" შპს → შპს "ჯეო ლოჯისტიქსი". Strip trailing periods/extra quotes. Output clean format: შპს "Company Name".
   - CLIENT CONTACT INFO: If user mentions client's phone, email, or address, include them in the output "client_phone", "client_email", "client_address" fields.
   - SENDER OVERRIDES: If user mentions changing their own business name, phone, email, address, or tax ID, include them in "sender_business_name", "sender_phone", "sender_email", "sender_address", "sender_tax_id" fields.
   - PAYMENT INSTRUCTIONS: If user mentions "bank transfer only" or "საბანკო გადარიცხვით", check if sender payment details contain bank info. If not, ask for bank details via clarification. If user provides new payment instructions, include in "sender_payment_instructions".
9. Output STRICT JSON. No extra fields. Use null for unknown numeric values, empty arrays for absent categories.
10. OUTPUT TONE: Use Title Case for 'desc'/'name' fields. Be extremely brief — short, impactful technical terms. No parentheses/metadata in descriptions. Put specifics into 'sub_categories'.
11. AMBIGUOUS REDUCTIONS: If no currency or percent indicated, default to CURRENCY (flat amount). Hours with no rate → return hours, hourly_rate = null (system applies default).

----------------------------
EXTRACTION STRATEGY
----------------------------
- STEP 1: Scan the ENTIRE text for currency totals (e.g., "$2300", "twelve hundred").
- STEP 2: Map totals to categories (Labor, Materials, Fees).
- STEP 3: ONLY then gather descriptions and sub-categories.
- LATE TOTAL RULE: Items listed first + price follows later → consolidate into ONE priced item with parts as sub_categories. Never leave items at $0.
- SEPARATE PRICES = SEPARATE ITEMS: If two items each have their OWN explicit price, they are ALWAYS separate items. NEVER merge them. "ERP system 45,000" + "3 servers at 8,500 each" = TWO separate items.

----------------------------
NATURAL LANGUAGE / SLANG RULESET (pragmatic)
----------------------------
- Accept trade slang: "bucks", "quid" → count as currency; "knock off", "hook him up" → credit/discount intent; "trip charge", "service call" → fee; common part names ("P-Trap", "SharkBite") → materials.
- MEASUREMENTS vs QUANTITY: "25 feet of pipe" → Qty: 1, Name/Desc: "25 feet of pipe". Do NOT extract '25' as quantity unless it refers to discrete units (e.g. "25 pipes").
- If explicit currency word omitted (e.g., "Take 20 off"), treat as CURRENCY (flat amount). Only infer percent if "percent" or "%" is explicitly used.
- THOUSANDS SEPARATOR: Spaces in numbers are thousands separators. "4 599" = 4599, "12 000" = 12000, "1 200 000" = 1200000. NEVER split "4 599" into qty=4 and price=599.
- LINE ITEM NUMBERING: When items are listed with leading numbers (e.g., "1 iPhone 15 Pro", "2 დამცავი ქეისი"), these are often LIST/LINE NUMBERS, not quantities. Use context to decide:
  - "1 iPhone 15 Pro 4 599 ლარი" → line #1, qty=1, price=4599 (NOT qty=1, price=4599 — but also NOT qty=4, price=599).
  - "2 დამცავი ქეისი 90 ლარად თითო" → line #2, qty=2, price=90 each (the word "თითო"/"each" confirms qty=2).
  - If "თითო"/"each"/"per unit" follows the price, the leading number IS the quantity. Otherwise, it's likely a line number with qty=1.
- AMBIGUOUS QUANTITY: If user implies a range or uncertainty (e.g. "3 or 4", "maybe 5 or 6"), ALWAYS extract the HIGHER number.
- If user mentions a rate earlier (e.g., “$90 an hour”) assume it persists for subsequent hourly items until explicitly changed.
- If user says "usual rate", "standard rate", or "same rate", leave rate fields as NULL (system will apply defaults).
- DAY REFERENCES: When user mentions "day", "half day", "workday", or "X days" for labor time, convert using #{hours_per_workday} hours per day. Examples: "three days" = #{three_days_hours} hours, "half day" = #{half_day_hours} hours.
- DATE EXTRACTION: If user mentions WHEN the work was done (e.g., "yesterday", "last Tuesday", "on February 5th", "this was from last week", "the job was on Monday", "set the date to...", "change the date to..."), extract this as the invoice date and return it in the "date" field. Use format "MMM DD, YYYY" (e.g., "Feb 07, 2026"). Today's date is #{today_for_prompt}. If no date is mentioned, return null for the "date" field.
- GEORGIAN DATE TERMS: "საწყისი თარიღი", "ინვოისის თარიღი", "გაცემის თარიღი" → invoice "date". "ბოლო ვადა", "ბოლო თარიღი", "ვადა", "გადახდის ვადა" → "due_date". "მიწოდების თარიღი" (delivery date), "დაწყების თარიღი" (start date), "დასრულების თარიღი" (completion date), "შესრულების თარიღი" (fulfillment date), "ჩაბარების თარიღი" (handover date), "საქმის დასრულების თარიღი", "სამსახურის დასრულების თარიღი" → these are NOT invoice or due dates. Add as a sub_category on the most relevant/main item. Do NOT put delivery/completion/start dates in the "date" or "due_date" fields.
- SUB_CATEGORY DATE FORMAT: When adding dates as sub_categories, use the DOCUMENT LANGUAGE for month names. Georgian docs: "მიწოდება: 15 მარტი, 2026", "დასრულება: 15 მარტი, 2026", "შესრულება: 20 აპრილი, 2026". English docs: "Delivery: Mar 15, 2026", "Completion: Mar 15, 2026". NEVER mix languages (e.g., WRONG: "შესრულების თარიღი: Mar 15, 2026").

----------------------------
CATEGORY RULES (must map correctly)
----------------------------
Categories: LABOR/SERVICE, MATERIALS, EXPENSES, FEES, CREDITS.
THESE ARE THE ONLY 5 CATEGORIES. You MUST classify every item into one of these. There is NO "other", "notes", "miscellaneous", or any other category. If an item does not clearly fit LABOR, EXPENSES, or FEES, classify it as MATERIALS.

LABOR:
- SERVICE ACTIONS: Implementation, deployment, installation, configuration, setup, migration, integration, consulting, training are ALWAYS labor/service — even if the object sounds like a product (e.g., "ERP system implementation" = SERVICE, "server installation" = SERVICE, "database migration" = SERVICE). Georgian: "დანერგვა", "ინსტალაცია", "კონფიგურაცია", "მიგრაცია", "ინტეგრაცია" = ALWAYS SERVICE.
- If multiple distinct services are mentioned, create separate labor entries.
- If user gives "2 hours, $100 total": treat as fixed $100 (flat). Do NOT infer $50/hr.
- Hours + rate → mode "hourly", include hours and rate fields. Flat total → mode "fixed", include price field and set hours=1 or include hours as metadata (per your schema).
- GEORGIAN HOURLY PATTERNS: "2 საათი 150 ლარი საათში" → hours=2, rate=150, mode="hourly". "3 საათი 100-ით" → hours=3, rate=100, mode="hourly". "კონსულტაცია 2 საათი 150 ლარი საათში" → desc="კონსულტაცია", hours=2, rate=150, mode="hourly". NEVER zero out explicit hours or rates.
- If user sets multiplier like "time and a half" or "double rate", compute the new rate from the default hourly rate only when no explicit hourly was spoken. If explicit hourly rate spoken — use it.
- Do not propagate explicit rates to other hours. Only apply explicit rates to the hour they are spoken. For any other hour, use the default rate if unspecified.
- USE SPECIFIC TITLES for the 'desc' field (e.g., "AC Repair", "Emergency Call Out"). ALWAYS use Title Case.
- Be concise but descriptive.#{' '}
- Put additional task details into 'sub_categories' ONLY if they add new information.
- FREE LABOR ITEMS: If user mentions "free", "no charge", "complimentary", "on the house" (Georgian: "უფასოდ", "უფასო", "უფასოდ ჩავუთვლი", "უფასოდ გავუკეთე") for a labor item, you MUST set price=0, hours=0, rate=0, mode="fixed", and taxable=false. Do NOT assign any default rate or price.

MATERIALS:
- Physical goods the client keeps or receives (servers, parts, equipment, supplies). NOT services/actions.
- "hardware" / "აპარატურა" / "equipment" = ONLY physical items (servers, devices, parts). Implementation, installation, configuration are NOT hardware.
- Extract ONLY the noun/item name, stripping action verbs.
- NAMING: When user says "used nails" or "got filters", the action verb ("used", "got", "bought", "grabbed") is NOT part of the item name. Extract just "Nails", "Filters". Only include adjectives that describe the item itself (e.g., "new filters" → "New Filters", "copper pipe" → "Copper Pipe").
#{target_is_georgian ? '- GEORGIAN NAMING: Keep material names in singular form (e.g., "ნაჯახი" for any quantity). Do NOT pluralize.' : '- TRANSLATION: If the input is in Georgian or any other non-English language, you MUST translate material names to English. E.g., "ნაჯახი" → "Axe", "ლურსმანი" → "Nail", "მილი" → "Pipe". Do NOT leave Georgian text in the name field.'}
- UNIT PRICE RULE: If a total price is given for a quantity (e.g., "4 items cost 60" or "4 axes... but put 60"), set qty=4 and unit_price=60/4. Do NOT assign total as unit_price.
- DISTINCT ITEMS: If user lists multiple named items (e.g. "used nails, used filters"), create SEPARATE material entries for each. Do NOT bundle them as subcategories.
- BUNDLING ONLY: Only bundle into subcategories when user gives a COLLECTIVE total (e.g. "materials were $500" or "parts cost 300 total"). In that case, create ONE item named "Materials" with that price, and list specific part names in 'sub_categories'.
- Extract QUANTITY into the 'qty' field (default 1).
- Extract UNIT PRICE (price per item) into 'unit_price'. If an item has no price mentioned, leave unit_price as null.
- DO NOT put "(x2)" or quantity info in the description/name if you are setting the 'qty' field.
- If user says "2 items at 40 each", 'qty' is 2 and 'unit_price' is 40.
- If quantity is "3 or 4", "3 to 4", use the HIGHER value (4) for the 'qty' field.
- Never include internal cost unless explicitly spoken (avoid exposing cost).

AMBIGUOUS ITEMS (Labor vs Materials):
- "Action + Object + Price" (e.g. "Replaced filter $25", "Cleaned vents $15") -> CLASSIFY AS LABOR/SERVICE. Name it "Filter Replacement" or "Vent Cleaning".
- "[System/Software] + [action noun] + Price" → ALWAYS LABOR. E.g., "ERP სისტემის დანერგვა 45000" → LABOR (desc: "ERP System Implementation", mode: fixed, price: 45000). The system name is the OBJECT of the service, not a product being sold.
- REDUNDANCY CHECK: Do NOT add a sub_category that just repeats the main title or is a variation of it. (e.g. if desc is "AC Repair", do NOT add "Repaired AC" as a subcategory). Subcategories are ONLY for additional details (e.g. specific part names, location) not implied by the title.
- Only classify as Materials if the spoken text purely describes the object (e.g. "The filter cost $25", "New filter: $25").
- If in doubt, prefer Labor/Service for tasks.
- SECTION TYPE DISAMBIGUATION: When you genuinely cannot determine which section an item belongs to (e.g., "100 ლარი" with no context, or an item that could equally be labor, materials, or fees), add a clarification with field: "section_type", guess: your best guess section name (e.g., "labor"), options: ["labor", "materials", "expenses", "fees"] (only include plausible sections), and question asking the user where to categorize the item. Place the item in your guessed section initially. Example: { "field": "section_type", "guess": "materials", "options": ["labor", "materials", "fees"], "question": "სად ჩავწეროთ ეს ელემენტი?" }
- CURRENCY DISAMBIGUATION: When the currency is ambiguous (e.g., user says a number with no currency indicator and the context doesn't make it clear, or mixed currency signals), add a clarification with field: "currency", guess: your best guess ISO code (e.g., "GEL"), options: ["GEL", "USD", "EUR"] (plausible currencies), and question asking which currency. Example: { "field": "currency", "guess": "GEL", "options": ["GEL", "USD", "EUR"], "question": "რომელი ვალუტა გამოვიყენოთ?" }

EXPENSES:
- Pass-through reimbursables (parking, tolls, Uber). Usually not taxed. Price numeric required.
- BUNDLING: If user gives a TOTAL PRICE for "expenses" (plural), create ONE main item named "Expenses" (or specific group name) with that price. List component details in 'sub_categories'.

FEES:
- Surcharges, disposal, rush fees, rent/lease payments, utility bills, late/penalty charges. Return `taxable: null` to defer to system settings unless user explicitly says "tax this" or "no tax".
- RENT/LEASE: Monthly rent, lease payments ("ქირა", "იჯარა") → ALWAYS classify as FEES. E.g., "February rent 1200" → Fee item { name: "February Rent", price: 1200 }.
- UTILITIES: Utility bills, communal payments ("კომუნალური", "კომუნალური გადასახადები") → FEES.
- PENALTIES: Late fees, fines, penalties ("ჯარიმა", "დაგვიანების ჯარიმა", "საჯარიმო") → FEES.
- BUNDLING: Same logic as Materials/Expenses. If a total fee amount is given for multiple fee types, bundle them into one main Fee item with sub-categories.

CREDITS:
- Each credit reason must be its own entry with its own amount.
- If user describes multiple reasons with separate amounts, return multiple credit entries.
- If user describes a single amount with multiple reasons (or no reason), use "Courtesy Credit" as the default reason. Do NOT return multiple credits for the same amount.
- Example: "Add a credit for 50" -> { "amount": 50, "reason": "Courtesy Credit" }.

----------------------------
DISCOUNT & CREDIT RULES
----------------------------
- Discounts = PRE-TAX by default. They reduce taxable base.
- "after tax", "off the total", "from the final amount" → treat as CREDIT (post-tax), NOT a discount.
- Ambiguous "take $X off" with no timing language → default to GLOBAL DISCOUNT (pre-tax).
- EXCLUSION: "discount everything except [category]" → FORBIDDEN to use "global_discount". Apply per-item to every OTHER category, leave excluded at 0.
- MUTUALLY EXCLUSIVE: each item has EITHER discount_flat OR discount_percent, NEVER BOTH.
- Percentage discount (e.g., "10% off") → use discount_percent. NEVER compute the flat equivalent.
- Flat discount (e.g., "$50 off") → use discount_flat.
- discount_percent ≤ 100. discount_flat ≤ item total price.
- Same rules apply to global_discount_flat/percent and labor_discount_flat/percent.
- DISCOUNT CLARIFICATION ORDER: When user mentions a discount but does NOT specify the amount:
  1. FIRST ask "რა ოდენობის ფასდაკლებაა?" / "What is the discount amount?" with field: "discount_amount", type: "text". Do NOT assume percentage.
  2. If user gives a number WITHOUT % sign:
     - If the number is > 100 → it is ALWAYS a flat amount. Apply discount_flat directly. Do NOT ask about type.
     - If the number is 1-100 (ambiguous range), return a clarification with field: "discount_type", type: "choice", options: #{ui_is_georgian ? '["ფიქსირებული", "პროცენტული"]' : '["Fixed", "Percentage"]'}. The frontend renders clickable buttons. ALL option values MUST be in #{ui_is_georgian ? 'Georgian' : 'English'}.
  3. If discount scope is ambiguous (multiple items exist and user didn't specify which), ask with field: "discount_scope", type: "multi_choice", options: [list ALL item names]. The frontend renders an accordion with an "Invoice Discount" button.
  4. If user answers "Invoice Discount" to a discount_scope question, apply as global_discount_flat or global_discount_percent. Otherwise apply per-item.
  5. NEVER ask "რომელი პროცენტით?" — always ask for amount first, then type if ambiguous, then scope if needed.
  6. If user explicitly says "X%" → just apply discount_percent=X. No clarification needed.
  7. If user explicitly says "$X off" or "X ლარი ფასდაკლება" → just apply discount_flat=X. No clarification needed.
  8. IMPORTANT: Use EXACTLY these field names: "discount_amount", "discount_type", "discount_scope".

----------------------------
TAX RULES
----------------------------
- TAXABLE FIELD DEFAULT: Return `taxable: null` to use system defaults.
- REMOVE TAX / NO TAX: "no tax" / "remove tax" / "მოაშორე გადასახადი" / "გადასახადი მოაშორე" / "ნუ დაადებ დღგ-ს" / "დღგ არ დაადო" / "დღგ არ მინდა" / "გადასახადი არ" / "გადასახადი არ მინდა" / "ნუ დაამატებ გადასახადს" / "tax off" → Set `labor_taxable: false` AND `taxable: false` on EVERY SINGLE item (labor, materials, expenses, fees). Also set tax_rate: null and tax_scope: null. No exceptions. This is a COMMAND.
- EXPLICIT "Tax everything except [X]": Set `taxable: false` for X, `taxable: true` for all others.
- EXPLICIT "Tax [X] only": Set `taxable: true` for X, `taxable: false` for others.
- EXPLICIT "Don't tax labor": Set `labor_taxable: false` AND `taxable: false` on EVERY labor_service_item.
- EXPLICIT "Don't tax materials": Set `taxable: false` on EVERY material item.
- PER-ITEM TAX EXEMPTION: When user says specific items are not taxable (e.g., "კექსი და ნამცხვარი არ იბეგრება", "iPhone is tax-free", "X და Y არ იბეგრება", "X-ზე დღგ არ დაადო"), find those items BY NAME across ALL sections and set `taxable: false` on each matching item. Leave all other items unchanged.
- TAX SCOPE: Use null if no instruction. "tax ONLY on parts" → `tax_scope: "materials"`.
- TAX RATES: "8% tax" → tax_rate: 8.0. Set on every item.
- GENERAL TAX (e.g., "add 18% tax", "დაამატე 18% დღგ"): Set `tax_rate` on every item. Leave `tax_scope: null`. Do NOT break apart per category.
- TAX IS NEVER A CLARIFICATION. "add X% tax" / "X% VAT" / "remove tax" → just apply it. Never ask.

----------------------------
CLARIFICATION QUESTIONS
----------------------------

████ NEVER-ASK RULES (ABSOLUTE — CHECK THESE FIRST) ████

Before generating ANY clarification, you MUST verify:
Does the user's text already contain an explicit number for this value?
If YES → DO NOT ASK. Just use the number. Return an EMPTY clarifications array if all values are explicit.

NEVER ask about a value that has an explicit number attached. Examples of EXPLICIT values that need ZERO clarification:
- "3 სერვერი, თითოეული 8,500 ლარად" → qty=3, unit_price=8500. DO NOT ASK "რა ღირდა სერვერები?"
- "სერვისის ღირებულება: 2,200 ლარი" → price=2200. DO NOT ASK "რა ღირდა სერვისი?"
- "45,000 ლარი" → price=45000. DO NOT ASK about price.
- "7% ფასდაკლება" → discount_percent=7. DO NOT ASK "რა პროცენტი იყო ფასდაკლება?"
- "18% დღგ" → tax_rate=18. DO NOT ASK "რა იყო დღგ-ს განაკვეთი?"
- "3 servers at 8,500 each" → qty=3, unit_price=8500. DO NOT ASK.
- "service cost: 2,200" → price=2200. DO NOT ASK.
- "7% discount" → discount_percent=7. DO NOT ASK.
- "add 18% VAT" → tax_rate=18. DO NOT ASK.

NEVER create clarifications about:
- Tax rates, tax scope, tax applicability → these are COMMANDS. Execute them.
- Discount percentages or discount scope → these are COMMANDS. Execute them.
- ANY value that has a number next to it, regardless of language.
- ANY rate (hourly rate, team rate, special rate) → system has defaults.
- Confirmation of something the user already stated (NEVER ask yes/no or true/false).
- CLIENT NAMES or CLIENT MATCHING. The system handles client matching automatically with interactive selection buttons. Just use the best matching name from EXISTING CLIENTS or the spoken name as-is. NEVER ask "which client?" or "which [name]?" in clarifications.

████ WHEN TO ASK (ONLY these narrow cases) ████

Ask ONLY when a category is mentioned but has NO number at all:
1. MISSING VALUES — category named, zero numeric info:
   - "parts were expensive" → no number → guess 0, ask "What was the cost for parts?"
   - "charged for labor" → no number → ask "What was the labor charge?"
2. VAGUE DESCRIPTORS replacing a number:
   - "some hours", "took a while", "a few items" → ask for exact count
   - "a lot", "significant amount" → ask for exact value
3. APPROXIMATE VALUES with hedging words:
   - "around 500", "just under 800", "about 2 hours" → ask for exact value
4. AMBIGUOUS NOTES/METADATA — warranty, guarantee, condition, note applies to MULTIPLE possible items:
   - THIS IS MANDATORY: When 2+ items exist and a note/warranty/guarantee is mentioned without specifying EXACTLY which items it covers, you MUST add a clarification question. Do NOT silently assume it applies to one item.
   - ONE QUESTION ONLY: Create exactly ONE clarification for each ambiguous note/warranty. NEVER split into multiple questions per item.
     WRONG (3 separate questions):
       { "field": "materials.warranty", "guess": "iPhone 15 Pro", "question": "..." }
       { "field": "materials.warranty", "guess": "დამცავი ქეისი", "question": "..." }
     CORRECT (1 combined question):
       { "field": "materials.warranty", "guess": "iPhone 15 Pro, დამცავი ქეისი, მონაცემთა გადატანის სერვისი", "question": "რომელ პროდუქტს ან მომსახურებას ეხება 1 წლიანი გარანტია?" }
   - DEFAULT GUESS = ALL ITEMS: When the note/warranty doesn't specify which items, your default guess should include ALL items from ALL sections (products AND services AND fees). Only guess fewer items if there's a clear reason to exclude some.
   - GUESS = ITEM NAME(S): The guess field lists which items you think the note applies to (comma-separated if multiple). NEVER the note text itself.
     WRONG: { "guess": "1 წლიანი გარანტია" } ← note text, NOT item names.
     CORRECT: { "guess": "iPhone 15 Pro, დამცავი ქეისი, მონაცემთა გადატანის სერვისი" } ← ALL item names.
   - GUESS REFLECTS JSON: Your initial JSON MUST immediately reflect the guess — attach the sub_category to ALL guessed item(s) right now, not after confirmation.
     The JSON output must ALWAYS match the guess. Do NOT leave guessed items without the sub_category.
   - QUESTION FORMAT: ALWAYS use "პროდუქტს ან მომსახურებას" (product or service) — NEVER just "პროდუქტს" alone. This ensures the user's answer covers services too.
     CORRECT: "რომელ პროდუქტს ან მომსახურებას ეხება 1 წლიანი გარანტია?"
     WRONG: "რომელ პროდუქტს ეხება 1 წლიანი გარანტია?" ← missing services!
   - Once the user clarifies, the corrected answer will be applied via chat.
   - If only ONE item exists, do NOT ask — just attach it.

If ALL values are explicit numbers AND no ambiguous notes, return clarifications: [] (empty array).

FORMAT: { "field": "[category].[field_name]", "guess": [best_guess_value], "question": "[short direct question]", "type": "[response_type]", "item_name": "[clean item name]" }
- For missing numbers: guess = your best numeric estimate (or 0)
- For ambiguous notes/warranty: guess = ITEM NAME(S) the note applies to (NEVER the note text itself)

ITEM NAME RULE (CRITICAL):
- Every clarification about a specific item MUST include "item_name" with the EXACT clean item name from sections (e.g., "შეკეთება", "ტელეფონი", "ქეისი").
- "item_name" must match a section item's "desc" field EXACTLY. No question phrases, no suffixes, no wrapping.
- The "question" field is for the QUESTION TEXT only (e.g., "რა სახის შეკეთებაა?"). NEVER embed item names inside question text as if they were the item name.
- WRONG: { "field": "labor.price", "question": "რა ფასად გსურთ შეკეთების?" } ← no item_name, name buried in question
- CORRECT: { "field": "labor.price", "item_name": "შეკეთება", "question": "რა ფასია?" }

RESPONSE TYPE TAXONOMY (every clarification MUST include a "type" field):
- "choice": user picks ONE option from a list. MUST include "options": ["opt1", "opt2", ...]. Example: section_type, currency.
- "multi_choice": user picks ONE OR MORE from a list. MUST include "options": [...]. Example: warranty scope across items.
- "yes_no": user confirms or denies. Example: approximate value confirmation.
- "text": user provides free-text input (number, name, date, etc.). Example: missing price, vague descriptor.
- "info": you are telling the user something, NO answer expected. Example: confirming an action, redirecting off-topic.

SAFETY RULES:
- If you cannot understand the input → return UNCHANGED values + empty clarifications array.
- NEVER re-ask a question. If user gave unexpected input, work with what they gave.
- Keep questions SHORT and conversational. End with ":" not "." when expecting input.
- Ask as many clarifications as the situation genuinely requires. Prefer fewer when possible, but do NOT artificially cap yourself. The frontend queues and displays them one at a time. If you have low-confidence guesses, add a "type": "info" clarification explaining your assumptions.

CLARIFICATION LANGUAGE (NON-NEGOTIABLE):
#{ui_is_georgian ? '- You MUST write ALL clarification question text in Georgian (ქართული). Every single "question" value MUST be in Georgian.' : '- You MUST write ALL clarification question text in English.'}

ADDITIONAL RULES:
- Prioritize the most impactful clarifications. You may add "type": "info" clarifications to tell the user about your assumptions.
- When you DO add a clarification with a guess, populate the corresponding JSON field with that SAME value
- MATH CHECK: Always double-check arithmetic. 7% of (3 × 8500) = 7% of 25500 = 1785.

CONVERSATION CONTEXT AWARENESS (CRITICAL):
- Input may contain "PREVIOUS Q&A CONTEXT" with numbered rounds of earlier questions and answers.
- Treat this as an ONGOING CONVERSATION. Incorporate ALL previous answers into JSON.
- NEVER re-ask a previously answered question. Use the answer directly.
- Each round builds on all previous rounds. Latest answer wins if contradictory.

----------------------------
OUTPUT JSON SCHEMA (must match exactly)
----------------------------
Return EXACTLY the JSON structure below (use null for unknown numeric, empty arrays for absent categories).
#{target_is_georgian ? '⚠️ REMINDER: All "desc", "name", "reason", "raw_summary", and "sub_categories" VALUES must be in Georgian (ქართული). Do NOT output English text in these fields.' : ''}

{
  "client": "",
  "address": "",
  "labor_hours": "",
  "fixed_price": "",
  "hourly_rate": null,
  "labor_tax_rate": null,
  "labor_taxable": null,
  "labor_discount_flat": "",
  "labor_discount_percent": "",
  "global_discount_flat": "",
  "global_discount_percent": "",
  "discount_tax_mode": null,
  "credits": [
    { "amount": "", "reason": "" }
  ],
  "currency": "ISO 4217 code (e.g., USD, GBP, EUR)",#{' '}
  "billing_mode": null,
  "tax_scope": "",
  "labor_service_items": [
    { "desc": "", "hours": "", "rate": "", "price": "", "mode": "hourly|fixed", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "materials": [
    { "name": "", "qty": "", "unit_price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "expenses": [
    { "name": "", "price": "", "taxable": false, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "fees": [
    { "name": "", "price": "", "taxable": null, "tax_rate": null, "discount_flat": "", "discount_percent": "", "sub_categories": [] }
  ],
  "date": null,
  "due_days": null,
  "due_date": null,
  "raw_summary": "",
  "clarifications": []
}

----------------------------
ERROR HANDLING (return ONLY JSON on error)
----------------------------
- Gibberish or unrelated to a job → {"error":"#{t('input_unclear', default: 'Input unclear - please try again')}"}
- Empty/silent input → {"error":"#{t('input_empty', default: 'Input empty')}"}
- Only non-billing talk → same error as gibberish.

----------------------------
FINAL REMINDERS (CRITICAL)
----------------------------
- #{target_is_georgian ? '████ LANGUAGE CHECK: Before returning, verify EVERY "desc", "name", "reason", "raw_summary", and "sub_categories" value is in Georgian (ქართული). If you wrote ANY English text in these fields, REWRITE it to Georgian NOW. ████' : lang_context}
- FREE ITEMS: If user says "უფასოდ", "უფასოდ ჩავუთვლი", "free", "no charge", "on the house" about ANY item, that item MUST have price=0, rate=0, hours=0, mode="fixed", taxable=false. This is NON-NEGOTIABLE.
- If ALL values are explicit, return clarifications: [] (EMPTY array).
PROMPT

      instruction_for_cache = normalize_gemini_instruction_for_cache(
        instruction,
        today_for_prompt: today_for_prompt,
        hours_per_workday: hours_per_workday,
        three_days_hours: three_days_hours,
        half_day_hours: half_day_hours
      )
      runtime_cache_context = gemini_runtime_instruction_context(
        today_for_prompt: today_for_prompt,
        hours_per_workday: hours_per_workday,
        three_days_hours: three_days_hours,
        half_day_hours: half_day_hours
      )

      gemini_model = ENV["GEMINI_PRIMARY_MODEL"].presence || "gemini-2.5-flash-lite"

      user_input_parts = []

      # Inject client list context for client matching (paid users only)
      if user_signed_in? && @profile.paid? && current_user.clients.any?
        client_names = current_user.clients.order(:name).limit(50).pluck(:id, :name).map { |id, name| "#{id}:#{name}" }.join(", ")
        user_input_parts << { text: "EXISTING CLIENTS (MUST USE EXACT DB NAME if match found — ignore legal-form order differences like შპს before/after name, and ignore quote style differences): #{client_names}" }
      end

      # Inject sender payment instructions for bank transfer intelligence
      payment_info = @profile.payment_instructions.to_s.strip
      if payment_info.present?
        user_input_parts << { text: "SENDER PAYMENT INSTRUCTIONS (for reference): #{payment_info}" }
      end

      if is_manual_text
        user_input_parts << { text: "USER INPUT (MANUAL TEXT):\n#{params[:manual_text]}" }
      else
        audio = params[:audio]
        return render json: { error: t('no_audio') }, status: 400 unless audio

        if audio.size > 10.megabytes
          return render json: { error: t('audio_too_large') }, status: 413
        end

        browser_transcript = params[:browser_transcript].to_s.strip
        if browser_transcript.present?
          user_input_parts << {
            text: "BROWSER LIVE TRANSCRIPT (NOISY HINT, MAY CONTAIN ERRORS):\n#{browser_transcript}"
          }
        end

        audio_data = Base64.strict_encode64(audio.read)
        user_input_parts << { inline_data: { mime_type: audio.content_type, data: audio_data } }
      end

      raw = nil
      json = nil

      cache_key, cached_instruction_name = gemini_instruction_cached_content(
        api_key: api_key,
        model: gemini_model,
        instruction: instruction_for_cache
      )
      use_cached_instruction = cached_instruction_name.present?

      prompt_parts = []
      prompt_parts << { text: instruction } unless use_cached_instruction
      prompt_parts << { text: runtime_cache_context } if use_cached_instruction
      prompt_parts.concat(user_input_parts)

      thinking_budget = (ENV["GEMINI_THINKING_BUDGET"].presence || 2048).to_i

      body = gemini_generate_content(
        api_key: api_key,
        model: gemini_model,
        prompt_parts: prompt_parts,
        cached_instruction_name: (use_cached_instruction ? cached_instruction_name : nil),
        thinking_budget: thinking_budget
      )


      # Cache fallback: if cached instruction failed, retry same model without cache
      if use_cached_instruction && body["error"].present?
        Rails.logger.warn("GEMINI CACHE FALLBACK (#{gemini_model}): #{body["error"].to_json}")
        Rails.cache.delete(cache_key) if cache_key.present?

        fallback_parts = prompt_parts.dup
        fallback_parts.unshift({ text: instruction })

        body = gemini_generate_content(
          api_key: api_key,
          model: gemini_model,
          prompt_parts: fallback_parts,
          cached_instruction_name: nil,
          thinking_budget: thinking_budget
        )
      end

      if body["error"].present?
        Rails.logger.error("AI MODEL ERROR (#{gemini_model}): #{body["error"].to_json}")
        return render json: { error: t('ai_failed_response') }, status: 500
      end

      parts = body.dig("candidates", 0, "content", "parts")
      raw = parts&.reject { |p| p["thought"] }&.map { |p| p["text"] }&.join("\n")

      if raw.blank?
        Rails.logger.error "AI FAILURE: No raw text in response. Body: #{body.to_json}"
        return render json: { error: t('ai_failed_response') }, status: 500
      end

      Rails.logger.info "AI RAW RESPONSE (#{gemini_model}): #{raw}"

      # More robust JSON extraction to handle preamble or "thinking" blocks
      json_match = raw.match(/\{[\s\S]*\}/m)
      if json_match
        begin
          json = JSON.parse(json_match[0])
        rescue => e
          Rails.logger.error "AI JSON PARSE ERROR (#{gemini_model}): #{e.message}. Raw: #{raw}"
        end
      else
        Rails.logger.error "AI NO JSON FOUND IN RAW (#{gemini_model}): #{raw}"
      end

      return render json: { error: t('invalid_ai_output') }, status: 422 unless json

      Rails.logger.info "AI MODEL USED: #{gemini_model}"

      if json["error"]
        Rails.logger.warn "AI RETURNED ERROR: #{json["error"]}"
        return render json: { error: json["error"] }, status: 422
      end

      Rails.logger.info "AI_PROCESSED: #{json}"

      # Enforce Array Safety
      %w[labor_service_items materials expenses fees credits].each { |k| json[k] = Array(json[k]) }

      # --- EMPTY RESULT DETECTION ---
      # If AI returned a structurally valid JSON but with no meaningful data
      # (no sections, no items, no client, empty transcript), treat as empty audio
      has_any_items = json["labor_service_items"].any? { |i| i.is_a?(Hash) && (i["desc"].to_s.strip.present? || i["price"].to_s.strip.present? || i["hours"].to_s.strip.present?) } ||
                      json["materials"].any? { |i| i.is_a?(Hash) && (i["name"].to_s.strip.present? || i["unit_price"].to_s.strip.present?) } ||
                      json["expenses"].any? { |i| i.is_a?(Hash) && (i["name"].to_s.strip.present? || i["price"].to_s.strip.present?) } ||
                      json["fees"].any? { |i| i.is_a?(Hash) && (i["name"].to_s.strip.present? || i["price"].to_s.strip.present?) } ||
                      json["credits"].any? { |i| i.is_a?(Hash) && i["amount"].to_s.strip.present? }
      has_client = json["client"].to_s.strip.present?
      summary_text = json["raw_summary"].to_s.strip
      has_summary = summary_text.length > 5 && summary_text.split(/\s+/).size > 2

      unless has_any_items || has_client || has_summary
        Rails.logger.warn "AI RETURNED EMPTY RESULT: no items, no client, no meaningful summary"
        return render json: { error: t('empty_audio') }, status: 422
      end

      # --- POST-PROCESSING: Detect free items from original input ---
      # The AI sometimes ignores free-intent phrases and assigns a price anyway.
      # Scan the original input for free-intent patterns and zero out matching items.
      original_input = (params[:manual_text].presence || params[:browser_transcript].presence || json["raw_summary"]).to_s
      free_kw = /უფასოდ|უფასო|\bfree\b|no charge|complimentary|on the house/i
      if original_input.match?(free_kw)
        # Extract sentences (split on period) that contain a free keyword
        free_sentences = original_input.split(/\./).select { |s| s.match?(free_kw) }
        Rails.logger.info "FREE_DETECT: Found #{free_sentences.size} free sentence(s): #{free_sentences.inspect}"

        # For each labor item, check if it matches any free sentence
        json["labor_service_items"].each do |item|
          next unless item.is_a?(Hash)
          desc = item["desc"].to_s.strip
          desc_lower = desc.downcase

          matched = free_sentences.any? do |sentence|
            s = sentence.downcase.strip
            # 1. Direct: desc text appears in sentence
            s.include?(desc_lower) ||
            # 2. Word match: any significant word from desc appears in sentence
            desc_lower.split(/\s+/).any? { |w| w.length > 2 && s.include?(w) } ||
            # 3. Cross-language: Georgian stem in sentence matches English/Georgian keyword in desc
            [
              ["ფანჯარ", /window|ფანჯ/i], ["ფანჯრ", /window|ფანჯ/i],
              ["მაცივარ", /refrigerator|fridge|მაცივ/i], ["მაცივრ", /refrigerator|fridge|მაცივ/i],
              ["კარებ", /door|კარ/i], ["კარის", /door|კარ/i],
              ["სახურავ", /roof|სახურავ/i], ["ჭერ", /ceiling|ჭერ/i],
              ["შეკეთებ", /repair|შეკეთ/i], ["შეცვლ", /replac|შეცვლ/i],
              ["გათბობ", /heat|გათბობ/i], ["კონდიციონერ", /ac|air.?condition|კონდიც/i],
              ["ონკან", /faucet|tap|ონკან/i], ["საპირფარეშო", /toilet|bathroom|საპირფარეშო/i],
              ["სარკმელ", /window|ფანჯ/i], ["წყალ", /water|plumb|წყალ/i],
              ["ელექტრ", /electr|ელექტრ/i], ["მილ", /pipe|მილ/i]
            ].any? { |stem, pattern| s.include?(stem) && desc_lower.match?(pattern) }
          end

          Rails.logger.info "FREE_DETECT: Item '#{desc}' matched=#{matched}"

          if matched
            Rails.logger.info "FREE_ITEM_OVERRIDE: Zeroing '#{desc}' due to free-intent in input"
            item["price"] = 0
            item["hours"] = 0
            item["rate"] = 0
            item["mode"] = "fixed"
            item["taxable"] = false
          end
        end
      end

      # ---------- NORMALIZATION ----------

      hours = clean_num(json["labor_hours"])
      price = clean_num(json["fixed_price"])
      json["hourly_rate"] = clean_num(json["hourly_rate"]) if json["hourly_rate"]
      json["labor_hours"] = hours
      json["fixed_price"] = price

      effective_tax_rate = clean_num(json["labor_tax_rate"]).presence || @profile.tax_rate.to_s
      json["labor_tax_rate"] = effective_tax_rate

      # Pass Labor & Global Discounts
      json["labor_discount_flat"] = clean_num(json["labor_discount_flat"])
      json["labor_discount_percent"] = clean_num(json["labor_discount_percent"])
      json["global_discount_flat"] = clean_num(json["global_discount_flat"])
      json["global_discount_percent"] = clean_num(json["global_discount_percent"])

      # Pass Credit - REMOVE legacy single fields
      # json["credit_flat"] -> REMOVED
      # json["credit_reason"] -> REMOVED

      # Normalize Credits Array
      json["credits"] ||= []

      # Strict post-tax credit enforcement
      # If detecting "post_tax" mode, ensure we aren't applying discounts incorrectly,
      # but technically the prompt handles this by putting them in credits[].

      # Filter and Normalize Credits
      json["credits"] = json["credits"].map do |c|
        {
          "amount" => clean_num(c["amount"]),
          "reason" => c["reason"].to_s.strip.presence || I18n.t("courtesy_credit", default: "Courtesy Credit")
        }
      end.select { |c| c["amount"].present? && c["amount"] > 0 }

      # Pass Discount Tax Mode (pre_tax only, otherwise nil for profile default)
      # Post-tax discounts are PROHIBITED (must be credits).
      json["discount_tax_mode"] = json["discount_tax_mode"] == "pre_tax" ? "pre_tax" : nil


      # PASS labor_taxable through if provided (null means use scope default)
      l_taxable = json["labor_taxable"]
      json["labor_taxable"] = if l_taxable == true || l_taxable == "true"
        true
      elsif l_taxable == false || l_taxable == "false"
        false
      else
        nil
      end

      effective_tax_scope =
        json["tax_scope"].to_s.strip.presence ||
          @profile.tax_scope.to_s.strip.presence ||
          "total"

      json["tax_scope"] = effective_tax_scope

      # Use AI-detected billing_mode if provided, otherwise fall back to profile
      effective_mode = json["billing_mode"].to_s.strip.presence || mode
      json["billing_mode"] = effective_mode

      json["time"] =
        if effective_mode == "fixed"
          price.presence || ""
        else
          hours.presence || ""
        end

      json["sections"] = []

        # LABOR/SERVICE items (no price - tied to labor charge)
        # Unified Logic: Populate from top-level if array is empty
        if json["labor_service_items"].blank? && (json["labor_hours"].present? || json["fixed_price"].present?)
          # item_price removed (was unused)
          json["labor_service_items"] = [ {
            "desc" => (target_is_georgian ? "პროფესიონალური მომსახურება" : "Work performed"),
            "hours" => json["labor_hours"],
            "price" => json["fixed_price"],
            "mode" => json["billing_mode"] || "hourly",
            "rate" => json["hourly_rate"],
            "sub_categories" => []
          } ]
        end

      if json["labor_service_items"]&.any?
        # Safety: Promotion of spoken rate to Master Rate
        # Scan ALL items for the first mentions of a rate if global is missing
        if json["hourly_rate"].blank?
          first_rate_item = json["labor_service_items"].find { |i| i.is_a?(Hash) && i["rate"].present? }
          json["hourly_rate"] = clean_num(first_rate_item["rate"]) if first_rate_item
        end

        json["sections"] << {
          type: "labor",
          title: sec_labels[:labor],
          items: json["labor_service_items"].each_with_index.map do |item, idx|
            if item.is_a?(Hash)
              # Priority: If mode is fixed, use price. If hourly, use hours.
              item_mode = item["mode"].presence || json["billing_mode"] || "hourly"
              free_item = item["desc"].to_s.match?(/\bfree\b|no charge|უფასოდ|უფასო/i) ||
                          (!item["price"].nil? && item["price"].to_f == 0 && item["taxable"] == false)

              # Improved value mapping logic
              raw_hours = clean_num(item["hours"])
              raw_price = clean_num(item["price"])
              raw_rate  = clean_num(item["rate"])

              item_qty_or_amount, item_rate_val = if item_mode == "fixed"
                 # In fixed mode, we favor price, then rate, then hours.
                 [ raw_price.presence || raw_rate.presence || raw_hours.presence, @profile.hourly_rate ]
              else
                 # In hourly mode, we favor hours.
                 # If no hours but we have a price, that price should reflect the RATE, not the HOURS.
                 target_qty = raw_hours.presence || "1"
                 target_rate = if raw_hours.present?
                                 raw_rate.presence || raw_price.presence
                 else
                                 raw_price.presence || raw_rate.presence
                 end
                 [ target_qty, target_rate.presence || @profile.hourly_rate ]
              end

              if item_qty_or_amount.blank? && idx == 0
                item_qty_or_amount = (json["billing_mode"] == "fixed" ? clean_num(json["fixed_price"]) : clean_num(json["labor_hours"]))
              end

              # Safety: Only inherit top-level labor FLAt discount if there is exactly ONE labor item.
              # Percentage discounts can apply to all items (mathematically equivalent).
              inherit_flat_discount = json["labor_service_items"].size == 1
              inherit_percent_discount = true

              if free_item
                item_qty_or_amount = 0
                item_rate_val = 0
              end

              {
                desc: item["desc"].to_s.strip,
                price: item_qty_or_amount,
                rate: item_rate_val,
                mode: item_mode,
                # Fix: Inherit from global labor_taxable first, then fall back to scope.
                # If individual item has explicit taxable, use it. Otherwise check global labor_taxable. If still nil, use scope.
                taxable: if free_item
                           false
                         elsif !item["taxable"].nil?
                           to_bool(item["taxable"])
                         elsif !json["labor_taxable"].nil?
                           json["labor_taxable"]
                         else
                           (effective_tax_scope.include?("labor") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
                         end,
                tax_rate: clean_num(item["tax_rate"]),
                discount_flat: clean_num(item["discount_flat"].presence || (inherit_flat_discount && json["labor_discount_flat"].present? && item["discount_flat"].blank? ? json["labor_discount_flat"] : "")),
                discount_percent: clean_num(item["discount_percent"].presence || (inherit_percent_discount && json["labor_discount_percent"].present? && item["discount_percent"].blank? ? json["labor_discount_percent"] : "")),
                sub_categories: Array(item["sub_categories"])
              }
            else
              {
                desc: item.to_s.strip,
                price: (idx == 0 ? (json["billing_mode"] == "fixed" ? json["fixed_price"] : json["labor_hours"]) : ""),
                discount_flat: clean_num(json["labor_discount_flat"].present? ? json["labor_discount_flat"] : ""),
                discount_percent: clean_num(json["labor_discount_percent"].present? ? json["labor_discount_percent"] : ""),
                sub_categories: []
              }
            end
          end
        }
      end

      # MATERIALS (physical goods with price)
      if json["materials"]&.any?
        json["sections"] << {
          type: "materials",
          title: sec_labels[:materials],
          items: json["materials"].map do |m|
            # Fallback: Extract quantity from description if missing in field
            d_text = (m["name"].presence || m["desc"].presence || "").to_s.strip
            q_val = clean_num(m["qty"])

            if q_val.nil? || q_val == 1.0
              # Try to find (x5), x5, (5), 5 off
              if match = d_text.match(/[\(\s]x?(\d+)[\)]?$/i) || d_text.match(/^(\d+)\s+x\s+/)
                 extracted_q = match[1].to_f
                 if extracted_q > 1
                   q_val = extracted_q
                   # key: remove (x2) from description? Maybe keeps it clean.
                   d_text = d_text.gsub(/[\(\s]x?(\d+)[\)]?$/i, "").strip.sub(/^(\d+)\s+x\s+/, "")
                 end
              elsif match = d_text.match(/^(\d+)\s+([A-Za-z]+)/) # "2 Fittings", but careful with "2 inch"
                  dist = match[1].to_f
                  # Simple heuristic: if quantity is 1 (default), and desc starts with "2 Fittings", assume 2 is qty
                  # BUT exclude common measurements like "2 inch", "3 mm"
                  word = match[2].downcase
                  unless %w[inch in mm cm m ft kg lb oz gal].include?(word)
                    if dist > 1
                       q_val = dist
                       d_text = d_text.sub(/^(\d+)\s+/, "")
                    end
                  end
              elsif match = d_text.match(/\s(\d+)\s+each$/i)
                  extracted_q = match[1].to_f
                  if extracted_q > 1
                    q_val = extracted_q
                    d_text = d_text.gsub(/\s(\d+)\s+each$/i, "").strip
                  end
              end
            end

            # Calculate price first so we can check if it's present
            item_price = clean_num(m["unit_price"])
            # Only apply tax scope if there's actually a price to tax
            item_taxable = if m["taxable"].nil?
                             item_price.present? && item_price > 0 && (effective_tax_scope.include?("material") || effective_tax_scope.include?("product") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
            else
                             to_bool(m["taxable"])
            end

            {
              desc: d_text,
              qty: q_val || 1,
              price: item_price,
              taxable: item_taxable,
              tax_rate: clean_num(m["tax_rate"]),
              discount_flat: clean_num(m["discount_flat"]),
              discount_percent: clean_num(m["discount_percent"]),
              sub_categories: Array(m["sub_categories"])
            }
          end
        }
      end

      # EXPENSES (pass-through reimbursements)
      if json["expenses"]&.any?
        expense_items = json["expenses"].map do |e|
          item_price = clean_num(e["price"])
          item_desc = (e["name"].presence || e["desc"].presence || "").to_s.strip
          # Skip items with no description
          next nil if item_desc.blank?

          item_taxable = if e["taxable"].nil?
                           item_price.present? && item_price > 0 && (effective_tax_scope.include?("expense") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
          else
                           to_bool(e["taxable"])
          end
          {
            desc: item_desc,
            price: item_price,
            taxable: item_taxable,
            tax_rate: clean_num(e["tax_rate"]),
            discount_flat: clean_num(e["discount_flat"]),
            discount_percent: clean_num(e["discount_percent"]),
            sub_categories: Array(e["sub_categories"])
          }
        end.compact

        # Only add section if there are valid items
        if expense_items.any?
          json["sections"] << {
            type: "expenses",
            title: sec_labels[:expenses],
            items: expense_items
          }
        end
      end

      # FEES (surcharges - income)
      if json["fees"]&.any?
        fee_items = json["fees"].map do |f|
          item_price = clean_num(f["price"])
          item_desc = (f["name"].presence || f["desc"].presence || "").to_s.strip
          # Skip items with no description
          next nil if item_desc.blank?

          item_taxable = if f["taxable"].nil?
                           item_price.present? && item_price > 0 && (effective_tax_scope.include?("fee") || effective_tax_scope.include?("surcharge") || effective_tax_scope.include?("all") || effective_tax_scope.include?("total"))
          else
                           to_bool(f["taxable"])
          end
          {
            desc: item_desc,
            price: item_price,
            taxable: item_taxable,
            tax_rate: clean_num(f["tax_rate"]),
            discount_flat: clean_num(f["discount_flat"]),
            discount_percent: clean_num(f["discount_percent"]),
            sub_categories: Array(f["sub_categories"])
          }
        end.compact

        # Only add section if there are valid items
        if fee_items.any?
          json["sections"] << {
            type: "fees",
            title: sec_labels[:fees],
            items: fee_items
          }
        end
      end

      # ── Strip AI-generated client clarifications (backend handles client matching) ──
      if json["clarifications"].is_a?(Array)
        json["clarifications"].reject! { |c| c.is_a?(Hash) && c["field"].to_s.match?(/\bclient\b/i) && c["field"] != "client_match" }
      end

      # ── Auto-upgrade clarifications: merge prices+qty, fix discount, convert tax ──
      auto_upgrade_clarifications!(json, (params[:language] || lang).to_s)

      # ── Client Matching Post-Processing (paid users only) ──
      recipient_info = nil
      if user_signed_in? && @profile.paid? && json["client"].present?
        client_name = json["client"].to_s.strip
        norm_spoken = normalize_client_name(client_name)

        # Tier 1: Exact match — first try ILIKE, then normalized name comparison
        exact_match = current_user.clients.where("name ILIKE ?", client_name).first
        unless exact_match
          exact_match = current_user.clients.detect { |c| normalize_client_name(c.name) == norm_spoken } if norm_spoken.present?
        end

        if exact_match
          recipient_info = { "client_id" => exact_match.id, "name" => exact_match.name, "email" => exact_match.email, "phone" => exact_match.phone, "address" => exact_match.address }
          json["client"] = exact_match.name
          # Ask user to confirm this is the right client
          confirm_q = I18n.locale.to_s == "ka" ? t("client_exists_confirm") : t("client_exists_confirm")
          json["clarifications"] ||= []
          json["clarifications"] << { "field" => "client_confirm_existing", "type" => "yes_no", "question" => confirm_q, "client_name" => exact_match.name, "client_id" => exact_match.id }
        else
          # Tier 2: Fuzzy match — ILIKE pattern + normalized comparison
          safe_name = client_name.gsub(/[%_]/, "")
          similar = current_user.clients.where("name ILIKE ?", "%#{safe_name}%").limit(10).to_a
          # Also find by normalized name if ILIKE missed them
          if norm_spoken.length >= 3
            current_user.clients.each do |c|
              norm_db = normalize_client_name(c.name)
              if norm_db.include?(norm_spoken) || norm_spoken.include?(norm_db)
                similar << c unless similar.any? { |s| s.id == c.id }
              end
            end
          end

          if similar.any?
            similar_with_counts = similar.map { |c| { "id" => c.id, "name" => c.name, "invoices_count" => c.logs.kept.count } }
              .sort_by { |c| -c["invoices_count"] }
              .first(3)
            best_guess = similar_with_counts.first["name"]
            question_text = I18n.locale.to_s == "ka" ? "მოიძებნა რამდენიმე მსგავსი კლიენტი:" : "Multiple similar clients found:"
            json["clarifications"] ||= []
            json["clarifications"] << { "field" => "client_match", "guess" => best_guess, "question" => question_text, "similar_clients" => similar_with_counts }
            recipient_info = { "client_id" => nil, "name" => client_name, "is_new" => true }
          else
            # No match at all — treat as new client
            recipient_info = { "client_id" => nil, "name" => client_name, "is_new" => true }
          end
        end
      end

      # ── Merge AI-extracted contact fields into recipient_info ──
      if recipient_info
        recipient_info["email"] ||= json["client_email"] if json["client_email"].present?
        recipient_info["phone"] ||= json["client_phone"] if json["client_phone"].present?
        recipient_info["address"] ||= json["client_address"] if json["client_address"].present?
      elsif json["client_email"].present? || json["client_phone"].present? || json["client_address"].present?
        recipient_info ||= { "client_id" => nil, "name" => json["client"], "is_new" => true }
        recipient_info["email"] = json["client_email"] if json["client_email"].present?
        recipient_info["phone"] = json["client_phone"] if json["client_phone"].present?
        recipient_info["address"] = json["client_address"] if json["client_address"].present?
      end

      # ── Build sender_info from AI-extracted sender overrides ──
      sender_info = nil
      sender_fields = %w[sender_business_name sender_phone sender_email sender_address sender_tax_id sender_payment_instructions]
      if sender_fields.any? { |f| json[f].present? }
        sender_info = {
          "business_name" => json["sender_business_name"],
          "phone" => json["sender_phone"],
          "email" => json["sender_email"],
          "address" => json["sender_address"],
          "tax_id" => json["sender_tax_id"],
          "payment_instructions" => json["sender_payment_instructions"]
        }.compact
      end

      final_response = {
        "client" => json["client"],
        "time" => json["time"],
        "raw_summary" => (is_manual_text ? nil : json["raw_summary"]),
        "sections" => json["sections"],
        "tax_scope" => json["tax_scope"],
        "billing_mode" => json["billing_mode"],
        "currency" => json["currency"],
        "hourly_rate" => json["hourly_rate"],
        "labor_tax_rate" => json["labor_tax_rate"],
        "labor_taxable" => json["labor_taxable"],
        "labor_discount_flat" => json["labor_discount_flat"],
        "labor_discount_percent" => json["labor_discount_percent"],
        "global_discount_flat" => json["global_discount_flat"],
        "global_discount_percent" => json["global_discount_percent"],
        "credits" => json["credits"],
        "discount_tax_mode" => json["discount_tax_mode"],
        "date" => json["date"],
        "due_days" => json["due_days"],
        "due_date" => json["due_date"],
        "clarifications" => Array(json["clarifications"]).select { |c| c.is_a?(Hash) && c["question"].present? },
        "recipient_info" => recipient_info,
        "sender_info" => sender_info
      }

      Rails.logger.info "FINAL NORMALIZED JSON: #{final_response.to_json}"

      # ── Analytics Event Tracking ──
      if user_signed_in?
        processing_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @_analytics_start_time rescue nil)
        source = is_manual_text ? "manual" : "voice"

        AnalyticsEvent.track!(
          user_id: current_user.id,
          event_type: AnalyticsEvent::VOICE_PROCESSING,
          duration_seconds: processing_time,
          source: source,
          metadata: { model: gemini_model }
        )

        unless is_manual_text
          AnalyticsEvent.track!(
            user_id: current_user.id,
            event_type: AnalyticsEvent::VOICE_RECORDING,
            duration_seconds: params[:audio_duration].to_f,
            source: "audio"
          )
        end

        AnalyticsEvent.track!(
          user_id: current_user.id,
          event_type: AnalyticsEvent::TRANSCRIPTION_SUCCESS,
          source: source,
          metadata: { model: gemini_model, has_clarifications: final_response["clarifications"].present? }
        )
      end

      render json: final_response

    rescue => e
      Rails.logger.error "AUDIO PROCESSING ERROR: #{e.message}\n#{e.backtrace.join("\n")}"

      # Track transcription failure
      if user_signed_in?
        AnalyticsEvent.track!(
          user_id: current_user.id,
          event_type: AnalyticsEvent::TRANSCRIPTION_FAILURE,
          metadata: { error: e.message.truncate(200) }
        )
      end

      render json: { error: t("processing_error") }, status: 500
    end
  end

  def refine_invoice
    api_key = ENV["GEMINI_API_KEY"]
    current_json = params[:current_json]
    user_message = params[:user_message].to_s.strip

    return render json: { error: t("input_too_short", default: "Input too short.") }, status: :unprocessable_entity if user_message.length < 2
    return render json: { error: "Missing invoice data" }, status: :unprocessable_entity if current_json.blank?

    # ── CLIENT CHANGE SHORTCUT: bypass AI entirely, just do client matching ──
    if ActiveModel::Type::Boolean.new.cast(params[:client_change_only])
      result = current_json.is_a?(String) ? (JSON.parse(current_json) rescue {}) : current_json.to_unsafe_h.to_h
      result = result.deep_stringify_keys
      new_client_name = user_message.to_s.strip
      result["client"] = new_client_name
      result["recipient_info"] = nil
      result["clarifications"] = []
      result["sections"] ||= []
      result["credits"] ||= []

      if user_signed_in? && @profile.paid?
        norm_spoken = normalize_client_name(new_client_name)

        # Tier 1: Exact match
        exact_match = current_user.clients.where("name ILIKE ?", new_client_name).first
        unless exact_match
          exact_match = current_user.clients.detect { |c| normalize_client_name(c.name) == norm_spoken } if norm_spoken.present?
        end

        if exact_match
          result["recipient_info"] = { "client_id" => exact_match.id, "name" => exact_match.name, "email" => exact_match.email, "phone" => exact_match.phone, "address" => exact_match.address }
          result["client"] = exact_match.name
          confirm_q = t("client_exists_confirm")
          result["clarifications"] << { "field" => "client_confirm_existing", "type" => "yes_no", "question" => confirm_q, "client_name" => exact_match.name, "client_id" => exact_match.id }
        else
          # Tier 2: Fuzzy match
          safe_name = new_client_name.gsub(/[%_]/, "")
          similar = current_user.clients.where("name ILIKE ?", "%#{safe_name}%").limit(10).to_a
          if norm_spoken.length >= 3
            current_user.clients.each do |c|
              norm_db = normalize_client_name(c.name)
              if norm_db.include?(norm_spoken) || norm_spoken.include?(norm_db)
                similar << c unless similar.any? { |s| s.id == c.id }
              end
            end
          end

          if similar.length == 1
            match = similar.first
            result["recipient_info"] = { "client_id" => match.id, "name" => match.name, "email" => match.email, "phone" => match.phone, "address" => match.address }
            result["client"] = match.name
            confirm_q = t("client_exists_confirm")
            result["clarifications"] << { "field" => "client_confirm_existing", "type" => "yes_no", "question" => confirm_q, "client_name" => match.name, "client_id" => match.id }
          elsif similar.length > 1
            similar_with_counts = similar.map { |c| { "id" => c.id, "name" => c.name, "invoices_count" => c.logs.kept.count } }
              .sort_by { |c| -c["invoices_count"] }
              .first(5)
            best_guess = similar_with_counts.first["name"]
            question_text = I18n.locale.to_s == "ka" ? "მოიძებნა რამდენიმე მსგავსი კლიენტი:" : "Multiple similar clients found:"
            result["clarifications"] << { "field" => "client_match", "guess" => best_guess, "question" => question_text, "similar_clients" => similar_with_counts }
            result["recipient_info"] = { "client_id" => nil, "name" => new_client_name, "is_new" => true }
          else
            result["recipient_info"] = { "client_id" => nil, "name" => new_client_name, "is_new" => true }
            add_q = I18n.locale.to_s == "ka" ? "გსურთ მეტი დეტალის მითითება \"#{new_client_name}\"-სთვის?" : "Would you like to add more details for \"#{new_client_name}\"?"
            result["clarifications"] << { "field" => "add_client_to_list", "type" => "yes_no", "question" => add_q, "guess" => nil, "client_name" => new_client_name }
          end
        end
      else
        # Not paid: just set name, no matching
        result["recipient_info"] = { "client_id" => nil, "name" => new_client_name, "is_new" => true }
        add_q = I18n.locale.to_s == "ka" ? "გსურთ მეტი დეტალის მითითება \"#{new_client_name}\"-სთვის?" : "Would you like to add more details for \"#{new_client_name}\"?"
        result["clarifications"] << { "field" => "add_client_to_list", "type" => "yes_no", "question" => add_q, "guess" => nil, "client_name" => new_client_name }
      end

      Rails.logger.info "CLIENT CHANGE DIRECT: #{new_client_name} → clarifications: #{result["clarifications"].map { |c| c["field"] }.join(", ")}"
      return render json: result
    end

    doc_language = params[:language] || @profile.try(:transcription_language) || session[:transcription_language] || @profile.try(:document_language) || "en"
    target_is_georgian = (doc_language == "ge" || doc_language == "ka")
    ui_is_georgian = (I18n.locale.to_s == "ka")
    today_for_prompt = Date.today.strftime("%b %d, %Y")

    lang_rule = if target_is_georgian
      "ALL text values (desc, name, reason, sub_categories) MUST be in Georgian (ქართული). JSON keys and section type values stay in English."
    else
      "ALL text values (desc, name, reason, sub_categories) MUST be in English. Translate Georgian text to English if needed. JSON keys and section type values stay in English."
    end

    # AI Assistant ALWAYS communicates in Georgian regardless of transcript language
    question_lang = "Georgian (ქართული)"
    conversation_history = params[:conversation_history].to_s

    # Serialize current_json properly - it arrives as a hash from params
    json_text = current_json.is_a?(String) ? current_json : current_json.to_json

    # Build client list context for refine (paid users only)
    client_list_context = ""
    if user_signed_in? && @profile.paid? && current_user.clients.any?
      client_names = current_user.clients.order(:name).limit(50).pluck(:id, :name).map { |id, name| "#{id}:#{name}" }.join(", ")
      client_list_context = "\nEXISTING CLIENTS: #{client_names}"
    end

    payment_context = ""
    if @profile.payment_instructions.to_s.strip.present?
      payment_context = "\nSENDER PAYMENT INSTRUCTIONS: #{@profile.payment_instructions.to_s.strip}"
    end

    # Static system instruction (domain rules, widget system, modification rules)
    # Separated from dynamic content for higher rule adherence via Gemini systemInstruction
    refine_system_instruction = <<~SYSINSTRUCTION
      You are the AI Assistant inside TalkInvoice — a voice-to-invoice web app for contractors (plumbers, electricians, techs, freelancers).

      HOW THE APP WORKS:
      1. User records or types job notes (e.g., "replaced filter, 2 hours, $150")
      2. A separate EXTRACTION AI converts that raw audio/text into structured invoice JSON with sections (labor, materials, expenses, fees), items, prices, taxes, discounts, and credits
      3. The invoice preview renders in the browser as a live editable form
      4. YOU take over: the user chats with you to refine, add, remove, or change anything on the invoice

      YOUR ROLE:
      - You receive the CURRENT invoice JSON + the user's chat message
      - You modify ONLY what the user asks for, keeping everything else EXACTLY as-is
      - When something is ambiguous, you return clarification questions with type/field metadata
      - The frontend renders your clarifications as interactive widgets (buttons, accordions, checkboxes, yes/no cards, input lists)
      - After the user answers all queued clarifications, their answers come back to you for the next round
      - You are NOT the extraction AI. You don't parse raw audio or transcripts. You work with structured JSON and conversational refinement instructions.
      - The user is typically a Georgian-speaking contractor. Always communicate in Georgian unless told otherwise.

      ████ DOMAIN RULES REFERENCE ████

      CATEGORY CLASSIFICATION:
      - LABOR/SERVICE: Implementation, deployment, installation, configuration, consulting, training, repair, cleaning — any ACTION. Georgian: "დანერგვა", "ინსტალაცია", "კონფიგურაცია", "შეკეთება", "გაწმენდა" = ALWAYS SERVICE.
      - MATERIALS/PRODUCTS: Physical goods the client keeps (servers, parts, equipment, supplies). NOT services/actions.
      - EXPENSES: Pass-through reimbursables (parking, tolls, Uber). Usually not taxed.
      - FEES: Surcharges, disposal, rush fees, rent/lease ("ქირა", "იჯარა"), utilities ("კომუნალური"), penalties ("ჯარიმა"). RENT/LEASE → ALWAYS FEES.
      - CREDITS: Each credit = { amount, reason }. Default reason: "Courtesy Credit". Post-tax reductions ("off the total") = CREDIT, not discount.
      - AMBIGUOUS: "Action + Object + Price" (e.g., "Replaced filter $25") → LABOR. If genuinely unclear, ask with field: "section_type".
      - If in doubt, prefer Labor/Service for tasks, Materials for physical objects.

      ITEM NAMING:
      - Title Case for all desc/name fields (e.g., "Filter Replacement", "ფილტრის შეცვლა").
      - Strip action verbs from material names: "used nails" → "Nails". Only keep descriptive adjectives.
      - Georgian: Use NOMINATIVE/dictionary form for item names, NOT genitive or other cases. "ველოსიპედის" (genitive) → "ველოსიპედი" (nominative). Singular form for any quantity.
      - When user answers a question conversationally (e.g., "ველოსიპედის" answering "რისი დამატება გსურთ?"), normalize to proper item name form.

      DISCOUNT RULES:
      - Discounts are PRE-TAX by default. They reduce the taxable base.
      - "after tax" / "off the total" / "from the final amount" → treat as CREDIT (post-tax), NOT discount.
      - MUTUALLY EXCLUSIVE: each item has EITHER discount_flat OR discount_percent, NEVER BOTH.
      - Percentage → discount_percent. Flat amount → discount_flat. NEVER compute the flat equivalent of a percentage.
      - discount_percent ≤ 100. discount_flat ≤ item total price.
      - "discount everything except [category]" → apply per-item to every OTHER category, leave excluded at 0. Do NOT use global_discount.
      - DISCOUNT CLARIFICATION ORDER — THINK: WHAT → HOW MUCH → WHAT TYPE. Follow this EXACT sequence:
        1. SCOPE FIRST: If 2+ items exist and user did NOT specify WHICH items get a discount, you MUST ask SCOPE first with field: "discount_scope", type: "multi_choice", options: [all item desc/name values from current invoice]. The frontend renders an accordion grouped by category with an "Invoice Discount" button. Do NOT skip this step. Do NOT assume "all items".
        2. AMOUNT SECOND: After scope is known (user selected items OR only 1 item exists OR user specified which), ask for the discount amount with field: "discount_amount", type: "text". Do NOT assume percentage.
        3. TYPE THIRD: After user gives a number WITHOUT % sign:
           - If the number is > 100 → it is ALWAYS a flat amount. Apply discount_flat directly. Do NOT ask about type.
           - If the number is 1-100 (ambiguous range) for a SINGLE item, return a clarification with field: "discount_type", type: "choice", options: ["ფიქსირებული", "პროცენტული"].
           - For MULTIPLE items (2+) needing type selection in the SAME round, you MUST use a SINGLE clarification with field: "discount_type_multi", type: "multi_choice", options: [item names]. Include "amounts" map with guessed/known amounts per item (e.g., "amounts": {"ტელეფონი": 13, "ქეისი": 25}). Do NOT return multiple separate "discount_type" clarifications — combine them into ONE "discount_type_multi".
        4. If user answers "Invoice Discount" to a discount_scope question, apply as global_discount_flat or global_discount_percent (invoice-level). Otherwise apply per-item to the selected items.
        5. SHORTCUT: If user specifies percentage explicitly (e.g., "10%"), just apply it — no need to ask about type. If scope is clear (e.g., "discount on phone"), just apply it — no need to ask about scope. If only 1 item exists, skip scope. Only ask what's MISSING.
        6. IMPORTANT: Use EXACTLY these field names: "discount_amount", "discount_type", "discount_scope". The frontend uses these to trigger specific UI widgets.
        7. NEVER ask "რომელი პროცენტით?" — follow the WHAT → HOW MUCH → WHAT TYPE order strictly.

      TAX RULES:
      - Default: taxable = null (system applies defaults). Only set explicitly when user says so.
      - REMOVE TAX / NO TAX → Set labor_taxable:false AND taxable:false on EVERY SINGLE item. Also set tax_rate:null and tax_scope:null. This is a COMMAND, not a question.
      - "tax everything except [X]" → taxable:false for X, taxable:true for all others.
      - PER-ITEM TAX EXEMPTION: find items BY NAME, set taxable:false on each. Leave others unchanged.
      - PER-ITEM TAX RATES: When user specifies rates per item, apply EXACTLY:
        - Items with rate > 0 → taxable:true, tax_rate:<rate>
        - Items with rate = 0 → taxable:false, tax_rate:0. NEVER skip. NEVER default to 18%.
      - ZERO TAX PATTERNS (CRITICAL - all mean tax_rate:0, taxable:false):
        - "X 0-ია" = "X is 0" → X gets taxable:false, tax_rate:0
        - "X 0%" → X gets taxable:false, tax_rate:0
        - "X-ის დღგ 0%" → X gets taxable:false, tax_rate:0
        - "დანარჩენი 0" / "rest 0" / "others 0%" → ALL unmentioned items get taxable:false, tax_rate:0
        - "შეკეთება 0-ია, დანარჩენი 18" = შეკეთება gets 0%, everything else gets 18%
        - ZERO IS A VALID TAX RATE. Apply it. Do not ignore it. Do not ask about it.
      - TAX IS NEVER A CLARIFICATION. Just apply it. Never ask.
      - CRITICAL: When a batch answer contains tax instructions (e.g., [AI asked: "..." → User answered: "Set per-item tax rates..."]), you MUST apply those rates EXACTLY. Items listed with tax_rate=0 MUST get taxable:false. NEVER ignore 0% rates or default them to anything else. The number 0 means ZERO TAX, not "skip" or "unchanged".

      FREE ITEMS: "free" / "no charge" / "უფასოდ" / "უფასო" → price=0, hours=0, rate=0, mode="fixed", taxable=false.

      NEVER-ASK RULES:
      - NEVER ask about tax rates, tax scope, tax applicability — these are COMMANDS.
      - NEVER ask about discount percentages when user specifies them (e.g., "10%").
      - NEVER ask about ANY value that has an explicit number next to it.
      - NEVER ask about hourly rates, team rates, special rates.
      - NEVER confirm something the user already stated.

      QUESTION FORMATTING:
      - All questions MUST end with "?" (question mark).
      - Keep questions SHORT and conversational.
      - GEORGIAN GRAMMAR (CRITICAL):
        - NEVER use parenthesized plural suffixes like "პოზიცი(ებ)ს", "ელემენტ(ებ)ს", "ნივთ(ებ)ს".
        - NEVER use words like "პოზიცია", "ელემენტი", "ნივთი" to refer to invoice items.
        - For SCOPE questions: use "რას ეხება ...?" pattern.
        - GEORGIAN COPULA STRIPPING: "წითელია" → "წითელი", "მწვანეა" → "მწვანე".
        - Write questions as a native Georgian speaker would naturally ask them.

      FRONTEND WIDGET SYSTEM:
      Your clarifications trigger visual widgets based on type and field:
      - type: "choice" + options → renders clickable buttons (user picks one)
      - type: "multi_choice" + options → renders accordion with per-item checkboxes grouped by invoice category
      - type: "yes_no" → renders yes/no buttons
      - type: "text" → renders text input with optional guess pre-fill
      - type: "info" → shows info message, no answer needed (auto-advances)
      - type: "item_input_list" + items → renders multi-item input card. Each item has:
        - name: item label displayed to user
        - category: optional ("labor"/"materials"/"expenses"/"fees") — triggers category-specific behavior
        - inputs: array of {key, label, type("number"|"text"), value(optional pre-fill)}
        - toggle: optional {key, options[], default} for per-item mode switching
        Special toggles:
        - billing_mode: ["fixed","hourly"] → hourly splits single input into hours+rate pair
        - discount_type: ["fixed","percentage"] → green toggle, % symbol on percentage
        Use item_input_list for: collecting prices for multiple new items, discount amounts+types, warranty durations, descriptions, quantities — any per-item free-form data collection.
        On confirm: frontend sends formatted "item1: value1, item2: value2, ..." as user answer.
        IMPORTANT: When asking prices for multiple new items and some are LABOR/SERVICE category, include billing_mode toggle on those items so user can choose fixed/hourly.
      - field: "section_type" + type: "choice" → renders category picker with icons
      - field: "discount_scope" + type: "multi_choice" → renders accordion with "Invoice Discount" button
      - field: "discount_type_multi" + type: "multi_choice" → renders per-item fixed/percentage toggle widget. Include "amounts" map.
      Use these to create interactive, multi-step conversations. The frontend queues them and shows one at a time.
      You are ENCOURAGED (not forced) to use these widgets — pick the best widget for each situation. For simple yes/no use yes_no, for item selection use multi_choice, for per-item data collection use item_input_list.

      MULTI-INTENT HANDLING:
      When user's message contains multiple intents (e.g., add items + discounts + tax), apply everything you CAN directly and return clarifications ONLY for ambiguous parts. NEVER lose part of a multi-intent request.

      ████ END DOMAIN RULES ████

      MODIFICATION RULES:
      1. Only change what the user explicitly asks for. Keep everything else EXACTLY as-is.
      2. Return the COMPLETE modified JSON in the SAME structure as the input.
      3. DATES: Invoice date → "date" field. Due date → "due_date" field. Delivery/completion dates → sub_category on relevant item. Format: "MMM DD, YYYY".
      4. TAX: Apply per TAX RULES above.
      5. DISCOUNTS: Apply per DISCOUNT RULES above.
      6. ADDING ITEMS: Classify per CATEGORY CLASSIFICATION. Name per ITEM NAMING.
         - Labor: { desc, price, rate, mode: "hourly"|"fixed", taxable, tax_rate, discount_flat, discount_percent, sub_categories: [] }
         - Materials: { desc, qty (default 1), price, taxable, tax_rate, discount_flat, discount_percent, sub_categories: [] }
         - Expenses/Fees: { desc, price, taxable, tax_rate, discount_flat, discount_percent, sub_categories: [] }
         - PRICE REQUIRED: When adding new items without a price, you MUST ask.
           ██ MANDATORY: When adding 2+ new items, you MUST use a SINGLE type: "item_input_list" clarification to collect ALL missing values (price, quantity, etc.) in ONE card. NEVER ask about each item separately with individual text questions. ██
           For labor items in item_input_list, include billing_mode toggle so user can pick fixed/hourly. For materials, include a quantity input. NEVER assume a default price.
      6b. SUB_CATEGORIES RULE: sub_categories is an array of strings for additional details.
         - WARRANTY: add to sub_categories. If 2+ items, ask with field: "warranty_scope", type: "multi_choice".
         - NOTES/DESCRIPTION: add to sub_categories of the target item.
         - REDUNDANCY CHECK: Do NOT add a sub_category that repeats the main item name.
      7. REMOVING ITEMS: Remove from section's items array. If section becomes empty, remove the section.
      8. CLIENT: Update "client" field. Match against EXISTING CLIENTS if provided. Georgian convention: შპს "Company Name".
      8b. SENDER/FROM FIELDS: Only modify the specific field the user asked to change.
      9. CLARIFICATION ANSWERS: When user_message contains "[AI asked: ...]", apply the answer DIRECTLY. Do NOT re-ask the same question.
      10. FOLLOW-UP CLARIFICATIONS — USE EXISTING WIDGETS: After applying answers, if new ambiguity arises, use the SAME widget field names the frontend supports. ALWAYS prefer dedicated widgets over generic text questions.
      11. Keep "raw_summary" unchanged.
      12. CREDITS: Default reason: "Courtesy Credit".
      13. All clarification questions MUST be in Georgian (ქართული). Questions MUST end with "?".
      14. Preserve ALL existing fields even if you don't modify them.
      15. SECTION TYPE DISAMBIGUATION: field: "section_type", type: "choice" when genuinely unclear.
      16. CURRENCY DISAMBIGUATION: field: "currency", type: "choice" when ambiguous.
      17. NEVER generate clarifications about CLIENT NAMES or CLIENT MATCHING.
      18. RESPONSE TYPE TAXONOMY — every clarification MUST include a "type" field: "choice", "multi_choice", "yes_no", "text", "info", or "item_input_list".
      19. SAFETY: If confused, return UNCHANGED JSON + empty clarifications.
      20. Ask as many clarifications as needed — no hard limit. Use appropriate widget fields.
      21. Keep questions SHORT and conversational.

      Return ONLY valid JSON. No markdown fences, no explanation text, no preamble.
    SYSINSTRUCTION

    # Dynamic content (changes every request)
    prompt = <<~PROMPT
      LANGUAGE RULE: #{lang_rule}
      #{client_list_context}#{payment_context}

      CURRENT INVOICE STATE:
      #{json_text}

      USER'S INSTRUCTION: "#{user_message}"

      #{conversation_history.present? ? "CONVERSATION CONTEXT:\n#{conversation_history}" : ""}

      Today's date is #{today_for_prompt}.
      All clarification questions MUST be in #{question_lang}.
      #{ui_is_georgian ? 'Discount type options: ["ფიქსირებული", "პროცენტული"]. All option text MUST be in Georgian.' : 'Discount type options: ["Fixed", "Percentage"]. All option text MUST be in English.'}

      Return the modified JSON with clarifications if needed.
    PROMPT

    begin
      gemini_model = ENV["GEMINI_PRIMARY_MODEL"].presence || "gemini-2.5-flash-lite"
      thinking_budget = (ENV["GEMINI_REFINE_THINKING_BUDGET"].presence || ENV["GEMINI_THINKING_BUDGET"].presence || 4096).to_i

      body = gemini_generate_content(
        api_key: api_key,
        model: gemini_model,
        prompt_parts: [{ text: prompt }],
        thinking_budget: thinking_budget,
        system_instruction: refine_system_instruction
      )

      if body["error"].present?
        Rails.logger.warn("REFINE ERROR (#{gemini_model}): #{body["error"].to_json}")
        return render json: { error: t("processing_error") }, status: 500
      end

      parts = body.dig("candidates", 0, "content", "parts")
      raw = parts&.reject { |p| p["thought"] }&.map { |p| p["text"] }&.join("\n")

      if raw.blank?
        Rails.logger.warn("REFINE EMPTY RESPONSE")
        return render json: { error: t("processing_error") }, status: 500
      end

      Rails.logger.info "REFINE RAW (#{gemini_model}): #{raw}"

      json_match = raw.match(/\{[\s\S]*\}/m)
      unless json_match
        Rails.logger.error "REFINE NO JSON FOUND: #{raw}"
        return render json: { error: t("invalid_ai_output") }, status: 422
      end

      result = begin
        JSON.parse(json_match[0])
      rescue => e
        Rails.logger.error "REFINE JSON PARSE ERROR: #{e.message}"
        nil
      end

      unless result
        return render json: { error: t("invalid_ai_output") }, status: 422
      end

      # Ensure required arrays exist
      result["sections"] ||= []
      result["credits"] ||= []
      result["clarifications"] = Array(result["clarifications"]).select { |c| c.is_a?(Hash) && c["question"].present? }

      # Strip AI-generated client clarifications (backend handles client matching exclusively)
      # Broadened: reject any clarification with "client" in field OR whose options overlap with DB client names
      db_client_names = user_signed_in? ? current_user.clients.pluck(:name).map(&:downcase) : []
      result["clarifications"].reject! do |c|
        next false unless c.is_a?(Hash)
        field_match = c["field"].to_s.match?(/\bclient\b/i) && !%w[client_match client_confirm_existing add_client_to_list].include?(c["field"].to_s)
        options_match = c["options"].is_a?(Array) && c["options"].any? { |o| db_client_names.include?(o.to_s.downcase) }
        field_match || options_match
      end

      # Sanitize AI clarifications: validate types, flatten object options, reject client-question patterns
      valid_types = %w[choice multi_choice yes_no text info item_input_list tax_management]
      result["clarifications"].reject! do |c|
        next true unless c.is_a?(Hash)
        # Reject unknown types (keep if type missing — treat as text)
        if c["type"].present? && !valid_types.include?(c["type"].to_s)
          Rails.logger.warn "CLARIFICATION REJECTED (unknown type): #{c.inspect}"
          next true
        end
        # Reject if options contain objects instead of strings (causes [object Object])
        if c["options"].is_a?(Array) && c["options"].any? { |o| o.is_a?(Hash) }
          Rails.logger.warn "CLARIFICATION REJECTED (object in options): #{c['field']}"
          next true
        end
        # Reject if question mentions client/კლიენტ patterns (AI shouldn't ask about clients)
        q = c["question"].to_s
        if q.match?(/\b(client|კლიენტ)/i) && !%w[client_match client_confirm_existing add_client_to_list].include?(c["field"].to_s)
          Rails.logger.warn "CLARIFICATION REJECTED (client pattern in question): #{c['field']}"
          next true
        end
        false
      end

      # ── Auto-upgrade clarifications: merge prices+qty, fix discount, convert tax ──
      auto_upgrade_clarifications!(result, params[:language].to_s)

      # Client matching for refine_invoice responses (paid users only)
      # Skip if frontend already resolved client matching (user confirmed/denied)
      client_already_resolved = ActiveModel::Type::Boolean.new.cast(params[:client_match_resolved])
      if user_signed_in? && @profile.paid? && result["client"].present? && !client_already_resolved
        client_name = result["client"].to_s.strip
        current_client_name = params.dig(:current_json, :client).to_s.strip
        norm_spoken = normalize_client_name(client_name)

        # Tier 1: Exact match — ILIKE then normalized
        exact_match = current_user.clients.where("name ILIKE ?", client_name).first
        unless exact_match
          exact_match = current_user.clients.detect { |c| normalize_client_name(c.name) == norm_spoken } if norm_spoken.present?
        end

        if exact_match
          result["recipient_info"] = { "client_id" => exact_match.id, "name" => exact_match.name, "email" => exact_match.email, "phone" => exact_match.phone, "address" => exact_match.address }
          result["client"] = exact_match.name
          # Confirm existing client
          confirm_q = t("client_exists_confirm")
          result["clarifications"] << { "field" => "client_confirm_existing", "type" => "yes_no", "question" => confirm_q, "client_name" => exact_match.name, "client_id" => exact_match.id }
        else
          # Tier 2: Fuzzy match — ILIKE + normalized comparison, exclude current client
          safe_name = client_name.gsub(/[%_]/, "")
          similar = current_user.clients.where("name ILIKE ?", "%#{safe_name}%").limit(10).to_a
          if norm_spoken.length >= 3
            current_user.clients.each do |c|
              norm_db = normalize_client_name(c.name)
              if norm_db.include?(norm_spoken) || norm_spoken.include?(norm_db)
                similar << c unless similar.any? { |s| s.id == c.id }
              end
            end
          end
          similar.reject! { |c| c.name.downcase == current_client_name.downcase } if current_client_name.present?

          if similar.length == 1
            match = similar.first
            result["recipient_info"] = { "client_id" => match.id, "name" => match.name, "email" => match.email, "phone" => match.phone, "address" => match.address }
            result["client"] = match.name
          elsif similar.length > 1
            similar_with_counts = similar.map { |c| { "id" => c.id, "name" => c.name, "invoices_count" => c.logs.kept.count } }
              .sort_by { |c| -c["invoices_count"] }
              .first(3)
            best_guess = similar_with_counts.first["name"]
            question_text = I18n.locale.to_s == "ka" ? "მოიძებნა რამდენიმე მსგავსი კლიენტი:" : "Multiple similar clients found:"
            result["clarifications"] << { "field" => "client_match", "guess" => best_guess, "question" => question_text, "similar_clients" => similar_with_counts }
            result["recipient_info"] = { "client_id" => nil, "name" => client_name, "is_new" => true }
          else
            result["recipient_info"] = { "client_id" => nil, "name" => client_name, "is_new" => true }
            add_q = I18n.locale.to_s == "ka" ? "გსურთ მეტი დეტალის მითითება \"#{client_name}\"-სთვის?" : "Would you like to add more details for \"#{client_name}\"?"
            result["clarifications"] << { "field" => "add_client_to_list", "type" => "yes_no", "question" => add_q, "guess" => nil, "client_name" => client_name }
          end
        end
      end

      # Merge AI-extracted contact fields into recipient_info for refine
      ri = result["recipient_info"]
      if ri
        ri["email"] ||= result["client_email"] if result["client_email"].present?
        ri["phone"] ||= result["client_phone"] if result["client_phone"].present?
        ri["address"] ||= result["client_address"] if result["client_address"].present?
      elsif result["client_email"].present? || result["client_phone"].present? || result["client_address"].present?
        result["recipient_info"] = { "client_id" => nil, "name" => result["client"], "is_new" => true,
          "email" => result["client_email"], "phone" => result["client_phone"], "address" => result["client_address"] }.compact
      end

      # Build sender_info from AI-extracted sender overrides for refine
      s_fields = %w[sender_business_name sender_phone sender_email sender_address sender_tax_id sender_payment_instructions]
      if s_fields.any? { |f| result[f].present? }
        result["sender_info"] = {
          "business_name" => result["sender_business_name"],
          "phone" => result["sender_phone"],
          "email" => result["sender_email"],
          "address" => result["sender_address"],
          "tax_id" => result["sender_tax_id"],
          "payment_instructions" => result["sender_payment_instructions"]
        }.compact
      end

      # Sort clarifications: client fields first, then AI questions
      client_fields = %w[client_confirm_existing client_match add_client_to_list]
      result["clarifications"].sort_by! { |c| client_fields.include?(c["field"].to_s) ? 0 : 1 }

      Rails.logger.info "REFINE RESULT: #{result.to_json}"
      render json: result

    rescue => e
      Rails.logger.error "REFINE ERROR: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: t("processing_error") }, status: 500
    end
  end

  def gemini_generate_content(api_key:, model:, prompt_parts:, cached_instruction_name: nil, temperature: 0, thinking_budget: 0, system_instruction: nil)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = thinking_budget > 0 ? 60 : 30
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
    gen_config = { temperature: temperature }
    gen_config[:thinkingConfig] = { thinkingBudget: thinking_budget } if thinking_budget > 0
    payload = {
      contents: [ { parts: prompt_parts } ],
      generationConfig: gen_config
    }
    payload[:systemInstruction] = { parts: [{ text: system_instruction }] } if system_instruction.present?
    payload[:cachedContent] = cached_instruction_name if cached_instruction_name.present?
    req.body = payload.to_json

    res = http.request(req)
    JSON.parse(res.body) rescue {}
  rescue => e
    Rails.logger.error("GEMINI REQUEST ERROR (#{model}): #{e.message}")
    { "error" => { "message" => e.message } }
  end


  def normalize_gemini_instruction_for_cache(instruction, today_for_prompt:, hours_per_workday:, three_days_hours:, half_day_hours:)
    normalized = instruction.to_s.dup

    normalized.gsub!(
      "convert using #{hours_per_workday} hours per day. Examples: \"three days\" = #{three_days_hours} hours, \"half day\" = #{half_day_hours} hours.",
      "convert using HOURS_PER_WORKDAY hours per day. Examples: \"three days\" = HOURS_PER_WORKDAY_x3 hours, \"half day\" = HOURS_PER_WORKDAY_div2 hours."
    )
    normalized.gsub!("Today's date is #{today_for_prompt}.", "Today's date is CURRENT_DATE.")

    normalized
  end


  def gemini_runtime_instruction_context(today_for_prompt:, hours_per_workday:, three_days_hours:, half_day_hours:)
    <<~TEXT.strip
      RUNTIME CONTEXT (overrides cached placeholders):
      - Today's date is #{today_for_prompt}.
      - For day references, use #{hours_per_workday} hours per day.
      - Example conversions: three days = #{three_days_hours} hours, half day = #{half_day_hours} hours.
    TEXT
  end


  def gemini_instruction_cached_content(api_key:, model:, instruction:)
    return [ nil, nil ] if api_key.blank?
    return [ nil, nil ] if ENV["GEMINI_PROMPT_CACHE_ENABLED"].to_s.downcase == "false"

    fingerprint = Digest::SHA256.hexdigest("#{model}\n#{instruction}")
    cache_key = "gemini_instruction_cache:v2:#{fingerprint}"
    cached_name = Rails.cache.read(cache_key).to_s.strip
    return [ cache_key, cached_name ] if cached_name.present?

    uri = URI("https://generativelanguage.googleapis.com/v1beta/cachedContents")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    http.open_timeout = 5

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
    requested_ttl = ENV["GEMINI_PROMPT_CACHE_TTL"].presence || "604800s"
    effective_ttl = requested_ttl

    req.body = {
      model: "models/#{model}",
      contents: [ {
        role: "user",
        parts: [ { text: instruction } ]
      } ],
      ttl: requested_ttl
    }.to_json

    res = http.request(req)
    body = JSON.parse(res.body) rescue {}

    if body["name"].blank? && requested_ttl != "86400s"
      effective_ttl = "86400s"
      req.body = {
        model: "models/#{model}",
        contents: [ {
          role: "user",
          parts: [ { text: instruction } ]
        } ],
        ttl: effective_ttl
      }.to_json
      res = http.request(req)
      body = JSON.parse(res.body) rescue {}
    end

    created_name = body["name"].to_s.strip

    if created_name.present?
      local_expiry = (effective_ttl == "86400s") ? 20.hours : 6.days
      Rails.cache.write(cache_key, created_name, expires_in: local_expiry)
      return [ cache_key, created_name ]
    end

    Rails.logger.warn("GEMINI CACHE CREATE FAILED: #{body.to_json}")
    [ cache_key, nil ]
  rescue => e
    Rails.logger.warn("GEMINI CACHE ERROR: #{e.message}")
    [ nil, nil ]
  end


  def clean_num(val)
    return nil if val.blank?

    # Extract digits, decimal points, and negative signs
    # We strip expensive word-to-number logic since the AI prompt ensures numeric JSON output
    stripped = val.to_s.gsub(/[^0-9.-]/, "")
    return nil if stripped.blank?

    f = stripped.to_f
    (f % 1 == 0) ? f.to_i : f
  end

  def to_bool(val)
    return false if val.nil?
    str = val.to_s.downcase.strip
    [ "true", "1", "yes", "on" ].include?(str)
  end

  def paddle_api_base_url
    paddle_env = ENV["PADDLE_ENVIRONMENT"].to_s.downcase
    use_sandbox = paddle_env == "sandbox" || (paddle_env.blank? && !Rails.env.production?)
    use_sandbox ? "https://sandbox-api.paddle.com" : "https://api.paddle.com"
  end

  def paddle_transaction_details(api_key:, transaction_id:)
    urls = paddle_api_base_urls
    saw_forbidden = false

    urls.each do |base_url|
      uri = URI("#{base_url}/transactions/#{CGI.escape(transaction_id.to_s)}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        body = JSON.parse(resp.body) rescue {}
        data = body["data"]
        return data if data.present?
      else
        saw_forbidden ||= resp.code.to_i == 403
        Rails.logger.info("PADDLE TRANSACTION LOOKUP non-success: host=#{uri.host} code=#{resp.code}")
      end
    end

    saw_forbidden ? :forbidden : nil
  rescue => e
    Rails.logger.warn("PADDLE TRANSACTION LOOKUP ERROR: #{e.message}")
    nil
  end

  def alternate_paddle_api_base_url
    paddle_api_base_url == "https://sandbox-api.paddle.com" ? "https://api.paddle.com" : "https://sandbox-api.paddle.com"
  end

  def paddle_customer_portal_url(api_key:, customer_id:)
    return nil if customer_id.blank?

    last_status = nil

    paddle_api_base_urls.each do |base_url|
      uri = URI("#{base_url}/customers/#{CGI.escape(customer_id.to_s)}/portal-sessions")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        body = JSON.parse(resp.body) rescue {}
        data = body["data"] || {}
        url = data["url"].presence ||
          data.dig("urls", "general", "overview").presence ||
          data.dig("urls", "overview").presence ||
          data.dig("urls", "general").presence
        return url if url.present?

        Rails.logger.warn("PADDLE PORTAL SESSION missing URL: host=#{uri.host}")
      else
        last_status = resp.code.to_i
        body_snippet = resp.body.to_s.gsub(/\s+/, " ")[0, 300]
        Rails.logger.warn("PADDLE PORTAL SESSION non-success: host=#{uri.host} code=#{resp.code} body=#{body_snippet}")
      end
    end

    return :forbidden if [ 401, 403 ].include?(last_status)
    return :customer_missing if last_status == 404

    nil
  rescue => e
    Rails.logger.warn("PADDLE PORTAL SESSION ERROR: #{e.message}")
    nil
  end

  def portal_deep_link(overview_url:, action:, profile:)
    return overview_url if action.blank? || action == "overview"

    parsed = URI.parse(overview_url) rescue nil
    return overview_url unless parsed

    base = "#{parsed.scheme}://#{parsed.host}"
    path_cpl = parsed.path.to_s.sub(%r{^/}, "")
    query_params = URI.decode_www_form(parsed.query.to_s).to_h rescue {}
    token = query_params["token"]

    sub_id = profile&.paddle_subscription_id.presence
    txn_id = billing_latest_completed_txn_id(profile)

    target_path = case action
    when "update_payment", "cancel"
      sub_id.present? ? "/subscriptions/#{sub_id}/#{path_cpl}" : "/#{path_cpl}"
    when "download_invoice"
      txn_id.present? ? "/payments/#{txn_id}/#{path_cpl}" : "/#{path_cpl}"
    else
      "/#{path_cpl}"
    end

    result = "#{base}#{target_path}"
    result += "?token=#{token}" if token.present?
    result
  rescue => e
    Rails.logger.warn("PORTAL DEEP LINK ERROR: #{e.message}")
    overview_url
  end

  def refresh_latest_subscription_id(profile:, api_key:, customer_id:)
    return if profile.blank? || api_key.blank? || customer_id.blank?

    all_rows = paddle_customer_transactions(api_key: api_key, customer_id: customer_id, limit: 50)
    rows = all_rows.reject { |row| zero_amount_transaction?(row) }

    latest_sub_row = rows.find { |row| row[:status_kind] == "completed" && row[:subscription_id].present? }
    latest_sub_row ||= rows.find { |row| row[:subscription_id].present? }
    latest_sub_id = latest_sub_row&.dig(:subscription_id)

    if latest_sub_id.present? && profile.respond_to?(:paddle_subscription_id) && profile.paddle_subscription_id != latest_sub_id
      profile.update_columns(paddle_subscription_id: latest_sub_id)
      Rails.logger.info("BILLING PORTAL: Refreshed subscription_id to #{latest_sub_id}")
    end

    # Also update the billing cache with the latest transaction ID for invoice links
    if rows.present?
      history_rows = normalize_billing_history_rows(rows)
      cached = read_subscription_billing_cache(profile) || {}
      write_subscription_billing_cache(
        profile: profile,
        payment_method: cached[:payment_method],
        last_payment: cached[:last_payment],
        history_rows: history_rows,
        next_billing: cached[:next_billing],
        next_charge: cached[:next_charge]
      )
    end
  rescue => e
    Rails.logger.warn("REFRESH LATEST SUBSCRIPTION ID ERROR: #{e.message}")
  end

  def billing_latest_completed_txn_id(profile)
    return nil if profile.blank?

    cached = read_subscription_billing_cache(profile)
    return nil unless cached.is_a?(Hash)

    rows = cached[:history_rows] || cached["history_rows"]
    return nil unless rows.is_a?(Array)

    completed = rows.find { |r| r.is_a?(Hash) && (r[:status_kind] || r["status_kind"]).to_s == "completed" }
    (completed[:id] || completed["id"]).to_s.presence if completed
  rescue
    nil
  end

  def paddle_customer_id_for_subscription(api_key:, subscription_id:)
    uri = URI("#{paddle_api_base_url}/subscriptions/#{CGI.escape(subscription_id.to_s)}")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{api_key}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 8
    http.open_timeout = 5

    resp = http.request(req)
    return nil unless resp.is_a?(Net::HTTPSuccess)

    body = JSON.parse(resp.body) rescue {}
    body.dig("data", "customer_id").to_s.presence
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION LOOKUP ERROR: #{e.message}")
    nil
  end

  def profile_paddle_customer_id(profile)
    return nil unless profile.respond_to?(:paddle_customer_id)

    profile.paddle_customer_id.to_s.presence
  end

  def load_subscription_billing_data(profile)
    @billing_payment_method_label = t("subscription_page.not_available")
    @billing_last_payment_label = t("subscription_page.not_available")
    @billing_history_rows = []
    @billing_next_billing_label = nil
    @billing_next_charge_label = nil

    return if profile.blank?

    cached_snapshot = read_subscription_billing_cache(profile)
    if cached_snapshot.present?
      cached_method = normalized_payment_method_label(cached_snapshot[:payment_method])
      @billing_payment_method_label = cached_method if cached_method.present?
      @billing_last_payment_label = cached_snapshot[:last_payment] if cached_snapshot[:last_payment].present?
      @billing_history_rows = normalize_billing_history_rows(cached_snapshot[:history_rows])
      @billing_next_billing_label = cached_snapshot[:next_billing] if cached_snapshot[:next_billing].present?
      @billing_next_charge_label = cached_snapshot[:next_charge] if cached_snapshot[:next_charge].present?
    end

    api_key = ENV["PADDLE_API_KEY"].to_s
    return if api_key.blank?

    customer_id = resolve_paddle_customer_id(profile: profile, api_key: api_key)
    return if customer_id.blank?

    # --- 1. Fetch transactions (single API call) ---
    all_rows = paddle_customer_transactions(api_key: api_key, customer_id: customer_id, limit: 50)
    # Filter out $0.00 transactions (payment method updates) from display
    rows = all_rows.reject { |row| zero_amount_transaction?(row) }
    history_rows = normalize_billing_history_rows(rows)
    @billing_history_rows = history_rows if history_rows.present?

    # --- 2. Always resolve the latest subscription_id from transactions ---
    # When a user has multiple subscriptions (e.g. from testing), the stored
    # paddle_subscription_id may be stale. Always prefer the latest one.
    latest_sub_row = rows.find { |row| row[:status_kind] == "completed" && row[:subscription_id].present? }
    latest_sub_row ||= rows.find { |row| row[:subscription_id].present? }
    latest_sub_id = latest_sub_row&.dig(:subscription_id)

    effective_subscription_id = latest_sub_id.presence || profile.paddle_subscription_id.presence
    if effective_subscription_id.present? && profile.respond_to?(:paddle_subscription_id) && profile.paddle_subscription_id != effective_subscription_id
      profile.update_columns(paddle_subscription_id: effective_subscription_id)
      Rails.logger.info("BILLING: Updated subscription_id to latest: #{effective_subscription_id}")
    end

    # --- 3. Fetch subscription data (single API call) → next billing + next charge ---
    if effective_subscription_id.present?
      subscription_data = paddle_subscription_data(api_key: api_key, subscription_id: effective_subscription_id)
      if subscription_data.present?
        next_billed_at = paddle_subscription_next_billing_time(subscription_data)
        @billing_next_billing_label = l(next_billed_at, format: :long) if next_billed_at.present?

        next_charge_label = paddle_subscription_next_charge_label(subscription_data)
        @billing_next_charge_label = next_charge_label if next_charge_label.present?

        # --- 3b. Detect scheduled cancellation and store the correct end date ---
        scheduled_change = subscription_data["scheduled_change"]
        sub_status = subscription_data["status"].to_s.downcase
        if scheduled_change.is_a?(Hash) && scheduled_change["action"] == "cancel"
          cancel_date = parse_paddle_time(scheduled_change["effective_at"])
          if cancel_date.present? && profile.has_attribute?(:paddle_cancelled_at)
            profile.update_columns(paddle_cancelled_at: cancel_date, paddle_subscription_status: "canceled") if profile.paddle_cancelled_at != cancel_date
          end
        elsif sub_status == "canceled"
          ends_at = parse_paddle_time(subscription_data["current_billing_period"]&.dig("ends_at"))
          if ends_at.present? && profile.has_attribute?(:paddle_cancelled_at) && profile.paddle_cancelled_at != ends_at
            profile.update_columns(paddle_cancelled_at: ends_at)
          end
        elsif profile.has_attribute?(:paddle_cancelled_at) && profile.paddle_cancelled_at.present? && sub_status == "active" && scheduled_change.blank?
          # Subscription reactivated — clear stale cancellation date
          profile.update_columns(paddle_cancelled_at: nil, paddle_subscription_status: "active")
        end
      end
    end

    # --- 4. Fetch payment method from dedicated API (reflects latest updates) ---
    fresh_method = paddle_customer_payment_method(api_key: api_key, customer_id: customer_id)
    fresh_method = normalized_payment_method_label(fresh_method)
    @billing_payment_method_label = fresh_method if fresh_method.present?

    # Fallback: extract from transaction payments array if API didn't return one
    if @billing_payment_method_label == t("subscription_page.not_available")
      card_label = all_rows.filter_map { |row| row[:payment_method_label].presence }.first
      card_label = normalized_payment_method_label(card_label)
      @billing_payment_method_label = card_label if card_label.present?
    end

    # --- 5. Last payment from latest completed non-zero transaction ---
    latest_paid = rows.find { |row| row[:status_kind] == "completed" }
    if latest_paid.present?
      @billing_last_payment_label = "#{latest_paid[:amount]} · #{latest_paid[:date]}"
    end

    # --- 6. Cache everything ---
    has_real_data = [
      @billing_payment_method_label != t("subscription_page.not_available"),
      @billing_last_payment_label != t("subscription_page.not_available"),
      @billing_history_rows.present?,
      @billing_next_billing_label.present?,
      @billing_next_charge_label.present?
    ].any?

    if has_real_data
      write_subscription_billing_cache(
        profile: profile,
        payment_method: @billing_payment_method_label,
        last_payment: @billing_last_payment_label,
        history_rows: @billing_history_rows,
        next_billing: @billing_next_billing_label,
        next_charge: @billing_next_charge_label
      )
    end
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING DATA ERROR: #{e.message}")
  end

  def resolve_paddle_customer_id(profile:, api_key:)
    customer_id = profile_paddle_customer_id(profile)
    if customer_id.blank? && profile.paddle_subscription_id.present?
      customer_id = paddle_customer_id_for_subscription(api_key: api_key, subscription_id: profile.paddle_subscription_id)
    end

    if customer_id.blank?
      email = profile.paddle_customer_email.presence || profile.email.presence || profile.user&.email
      customer_id = paddle_customer_id_for_email(api_key: api_key, email: email)
    end

    if customer_id.present? && profile.respond_to?(:paddle_customer_id) && profile.paddle_customer_id.blank?
      profile.update_columns(paddle_customer_id: customer_id)
    end

    customer_id
  end

  def paddle_customer_id_for_email(api_key:, email:)
    return nil if email.blank?

    body = paddle_get_json(api_key: api_key, path: "/customers", params: { email: email })
    customers = paddle_collection_data(body)
    customer = customers.find do |item|
      item_email = item["email"].to_s
      item_email.present? && item_email.casecmp(email.to_s).zero?
    end

    customer&.dig("id").to_s.presence
  rescue => e
    Rails.logger.warn("PADDLE CUSTOMER LOOKUP BY EMAIL ERROR: #{e.message}")
    nil
  end

  def paddle_customer_payment_method(api_key:, customer_id:)
    return nil if customer_id.blank?

    body = paddle_get_json(
      api_key: api_key,
      path: "/customers/#{CGI.escape(customer_id.to_s)}/payment-methods",
      params: { per_page: 1 }
    )
    method = paddle_collection_data(body).first

    if method.blank? && body.is_a?(Hash)
      body = paddle_get_json(
        api_key: api_key,
        path: "/payment-methods",
        params: { customer_id: customer_id, per_page: 1 }
      )
      method = paddle_collection_data(body).first
    end

    return nil if method.blank?

    brand = method["card_brand"].presence ||
      method.dig("card", "brand").presence ||
      method.dig("details", "card", "brand").presence ||
      method.dig("card_details", "brand").presence
    last4 = method["last4"].presence ||
      method.dig("card", "last4").presence ||
      method.dig("details", "card", "last4").presence ||
      method.dig("card_details", "last4").presence
    type = method["type"].presence ||
      method["payment_method_type"].presence ||
      method.dig("details", "type").presence

    if brand.present? && last4.present?
      "#{brand.to_s.titleize} •••• #{last4}"
    elsif type.present?
      type.to_s.titleize
    end
  rescue => e
    Rails.logger.warn("PADDLE PAYMENT METHOD LOOKUP ERROR: #{e.message}")
    nil
  end

  def paddle_customer_transactions(api_key:, customer_id:, limit: 10)
    return [] if customer_id.blank?

    body = paddle_get_json(
      api_key: api_key,
      path: "/transactions",
      params: { customer_id: customer_id, per_page: limit }
    )
    transactions = paddle_collection_data(body)

    if transactions.blank? && body.is_a?(Hash)
      body = paddle_get_json(
        api_key: api_key,
        path: "/transactions",
        params: { "customer_id[]" => customer_id, per_page: limit }
      )
      transactions = paddle_collection_data(body)
    end

    rows = transactions.map do |tx|
      billed_at = parse_paddle_time(tx["billed_at"] || tx["created_at"] || tx["updated_at"])
      date_label = billed_at.present? ? l(billed_at, format: :long) : t("subscription_page.not_available")
      next_billing_at = paddle_transaction_next_billing_time(tx)
      next_billing_label = next_billing_at.present? ? l(next_billing_at, format: :long) : nil
      status_raw = tx["status"].to_s.downcase
      status_kind = billing_history_status_kind(status_raw)
      status_label = if status_kind == "completed"
        "Completed"
      elsif status_kind == "failed"
        "Failed"
      elsif status_raw.present?
        status_raw.humanize
      else
        t("subscription_page.not_available")
      end
      amount_label = format_paddle_transaction_amount(tx)
      invoice_id = tx["invoice_id"].presence || tx.dig("invoice", "id").presence || tx.dig("details", "invoice_id").presence
      receipt_url = tx["invoice_url"].presence ||
        tx["receipt_url"].presence ||
        tx.dig("invoice", "url").presence ||
        tx.dig("invoice", "hosted_url").presence ||
        tx.dig("invoice", "download_url").presence ||
        tx.dig("details", "invoice", "url").presence

      {
        id: tx["id"].to_s,
        subscription_id: tx["subscription_id"].to_s.presence,
        date: date_label,
        next_billing_label: next_billing_label,
        amount: amount_label,
        status: status_label,
        status_kind: status_kind,
        status_raw: status_raw,
        receipt_url: receipt_url,
        invoice_id: invoice_id,
        payment_method_label: paddle_payment_method_label_from_transaction(tx)
      }
    end.compact

    rows.first(limit)
  rescue => e
    Rails.logger.warn("PADDLE TRANSACTIONS LIST ERROR: #{e.message}")
    []
  end

  def billing_history_status_kind(status_raw)
    raw = status_raw.to_s.downcase
    return "completed" if %w[completed complete paid billed succeeded successful success processed settled].include?(raw)
    return "failed" if %w[failed failure past_due past-due canceled cancelled declined refused rejected error].include?(raw)

    nil
  end

  def zero_amount_transaction?(row)
    amount_str = row[:amount].to_s
    # Extract numeric portion, e.g. "USD 0.00" → "0.00"
    numeric = amount_str.gsub(/[^0-9.]/, "")
    numeric.present? && numeric.to_f <= 0
  rescue
    false
  end

  def billing_upcoming_status?(status_raw)
    %w[ready draft incomplete pending scheduled].include?(status_raw.to_s.downcase)
  end

  def paddle_subscription_data(api_key:, subscription_id:)
    return {} if subscription_id.blank?

    body = paddle_get_json(api_key: api_key, path: "/subscriptions/#{CGI.escape(subscription_id.to_s)}", params: { include: "next_transaction" })
    body.is_a?(Hash) ? (body["data"] || {}) : {}
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION DATA LOOKUP ERROR: #{e.message}")
    {}
  end

  def paddle_subscription_next_charge_label(subscription_data)
    return nil unless subscription_data.is_a?(Hash)

    item = Array(subscription_data["items"]).first || {}
    price = item["price"] || {}
    unit_price = price["unit_price"]
    next_transaction = subscription_data["next_transaction"] || {}

    amount = next_transaction.dig("details", "totals", "grand_total")
    amount ||= next_transaction.dig("details", "totals", "total")
    amount ||= next_transaction["amount"].presence
    amount ||= if unit_price.is_a?(Hash)
      unit_price["amount"]
    else
      unit_price.presence
    end

    currency = if unit_price.is_a?(Hash)
      unit_price["currency_code"]
    else
      nil
    end
    currency = next_transaction.dig("details", "totals", "currency_code") if currency.blank?
    currency = next_transaction["currency_code"] if currency.blank?
    currency ||= price["currency_code"]
    currency ||= subscription_data["currency_code"]

    return nil if amount.blank?
    return nil if amount.to_f <= 0

    format_paddle_money(amount: amount, currency: currency.presence || "USD")
  rescue => e
    Rails.logger.warn("PADDLE SUBSCRIPTION NEXT CHARGE PARSE ERROR: #{e.message}")
    nil
  end

  def paddle_subscription_next_billing_time(subscription_data)
    return nil unless subscription_data.is_a?(Hash)

    candidates = [
      subscription_data["next_billed_at"],
      subscription_data["next_billing_at"],
      subscription_data.dig("next_payment", "due_at"),
      subscription_data.dig("next_transaction", "due_at"),
      subscription_data.dig("next_transaction", "scheduled_at"),
      subscription_data.dig("next_transaction", "scheduled_for"),
      subscription_data.dig("next_transaction", "billing_period", "starts_at"),
      subscription_data.dig("next_transaction", "billing_period", "ends_at"),
      subscription_data.dig("current_billing_period", "ends_at"),
      subscription_data.dig("billing_period", "ends_at")
    ].compact

    parsed = candidates.filter_map { |value| parse_paddle_time(value) }
    parsed.find { |time| time >= Time.current.beginning_of_day }
  end

  def paddle_transaction_next_billing_time(transaction)
    line_items = transaction.dig("details", "line_items")
    first_line_item = line_items.is_a?(Array) ? line_items.first : nil

    parse_paddle_time(
      transaction["due_at"] ||
      transaction["scheduled_at"] ||
      transaction["scheduled_for"] ||
      transaction.dig("billing_period", "starts_at") ||
      transaction.dig("billing_period", "ends_at") ||
      transaction.dig("details", "billing_period", "starts_at") ||
      transaction.dig("details", "billing_period", "ends_at") ||
      first_line_item&.dig("billing_period", "starts_at") ||
      first_line_item&.dig("billing_period", "ends_at") ||
      first_line_item&.dig("period", "starts_at") ||
      first_line_item&.dig("period", "ends_at")
    )
  end

  def hydrate_billing_history_receipts(api_key:, rows:)
    Array(rows).map do |row|
      symbolized_row = row.to_h.symbolize_keys
      next symbolized_row if symbolized_row[:receipt_url].present?

      if symbolized_row[:invoice_id].present?
        fallback_url = paddle_invoice_receipt_url(api_key: api_key, invoice_id: symbolized_row[:invoice_id])
        symbolized_row[:receipt_url] = fallback_url if fallback_url.present?
      end

      if symbolized_row[:receipt_url].blank? && symbolized_row[:id].present?
        tx_details = paddle_transaction_details(api_key: api_key, transaction_id: symbolized_row[:id])
        if tx_details.is_a?(Hash)
          detail_invoice_id = tx_details["invoice_id"].presence || tx_details.dig("invoice", "id").presence
          detail_receipt_url = tx_details["invoice_url"].presence ||
            tx_details["receipt_url"].presence ||
            tx_details.dig("invoice", "url").presence ||
            tx_details.dig("invoice", "hosted_url").presence ||
            tx_details.dig("invoice", "download_url").presence

          symbolized_row[:invoice_id] = detail_invoice_id if symbolized_row[:invoice_id].blank? && detail_invoice_id.present?
          symbolized_row[:receipt_url] = detail_receipt_url if detail_receipt_url.present?

          if symbolized_row[:receipt_url].blank? && symbolized_row[:invoice_id].present?
            fallback_url = paddle_invoice_receipt_url(api_key: api_key, invoice_id: symbolized_row[:invoice_id])
            symbolized_row[:receipt_url] = fallback_url if fallback_url.present?
          end
        end
      end

      symbolized_row
    end
  rescue => e
    Rails.logger.warn("PADDLE HISTORY RECEIPT HYDRATION ERROR: #{e.message}")
    rows
  end

  def normalized_payment_method_label(label)
    candidate = label.to_s.strip
    return nil if candidate.blank?

    generic_labels = %w[automatic manual subscription card]
    return nil if generic_labels.include?(candidate.downcase)

    candidate
  end

  def paddle_payment_method_label_from_transaction(transaction)
    return nil unless transaction.is_a?(Hash)

    payments = transaction["payments"]
    return nil unless payments.is_a?(Array)

    # Find the first successful (captured) payment with method_details
    payment = payments.find { |p| p.is_a?(Hash) && p["status"] == "captured" && p.dig("method_details", "card").present? }
    payment ||= payments.find { |p| p.is_a?(Hash) && p.dig("method_details", "card").present? }
    payment ||= payments.first
    return nil unless payment.is_a?(Hash)

    method_details = payment["method_details"] || {}
    card = method_details["card"] || {}

    # Paddle returns card brand as "type" (e.g. "visa", "mastercard")
    brand = card["type"] || card["brand"] || method_details["card_brand"] || method_details["brand"]
    last4 = card["last4"] || method_details["last4"] || method_details["card_last4"]

    if brand.present? && last4.present?
      "#{brand.to_s.titleize} •••• #{last4}"
    elsif brand.present?
      brand.to_s.titleize
    end
  end

  def paddle_invoice_receipt_url(api_key:, invoice_id:)
    return nil if invoice_id.blank?

    body = paddle_get_json(api_key: api_key, path: "/invoices/#{CGI.escape(invoice_id.to_s)}")
    data = body.is_a?(Hash) ? (body["data"] || {}) : {}

    data["url"].presence ||
      data["hosted_url"].presence ||
      data["download_url"].presence ||
      data["pdf_download_url"].presence
  rescue => e
    Rails.logger.warn("PADDLE INVOICE URL LOOKUP ERROR: #{e.message}")
    nil
  end

  def format_paddle_transaction_amount(transaction)
    totals = transaction.dig("details", "totals") || transaction["totals"] || {}
    amount = totals["grand_total"].presence || totals["total"].presence || transaction["amount"].presence
    currency = totals["currency_code"].presence || transaction["currency_code"].presence || "USD"

    format_paddle_money(amount: amount, currency: currency)
  end

  def format_paddle_money(amount:, currency:)
    return t("subscription_page.not_available") if amount.blank?

    amount_string = amount.to_s
    major_amount =
      if amount_string.include?(".")
        amount_string.to_f
      else
        amount_string.to_f / 100.0
      end

    "#{currency.to_s.upcase} #{format('%.2f', major_amount)}"
  rescue
    t("subscription_page.not_available")
  end

  def parse_paddle_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue
    nil
  end

  def paddle_collection_data(body)
    return [] unless body.is_a?(Hash)

    data = body["data"]
    data.is_a?(Array) ? data : []
  end

  def paddle_api_base_urls
    paddle_env = ENV["PADDLE_ENVIRONMENT"].to_s.downcase
    primary = paddle_api_base_url

    return [ primary ] if [ "sandbox", "production", "live" ].include?(paddle_env)

    [ primary, alternate_paddle_api_base_url ].compact.uniq
  end

  def paddle_get_json(api_key:, path:, params: {})
    return nil if api_key.blank?

    paddle_api_base_urls.each do |base_url|
      uri = URI("#{base_url}#{path}")
      filtered_params = params.to_h.reject { |_, value| value.blank? }
      uri.query = URI.encode_www_form(filtered_params) if filtered_params.present?

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 8
      http.open_timeout = 5

      resp = http.request(req)
      if resp.is_a?(Net::HTTPSuccess)
        return JSON.parse(resp.body) rescue {}
      end

      if resp.code.to_i == 429
        Rails.logger.warn("PADDLE GET rate-limited: path=#{path} host=#{uri.host} code=#{resp.code}")
        return nil
      end

      Rails.logger.info("PADDLE GET non-success: path=#{path} host=#{uri.host} code=#{resp.code}")
    end

    nil
  rescue => e
    Rails.logger.warn("PADDLE GET ERROR (#{path}): #{e.message}")
    nil
  end

  def read_subscription_billing_cache(profile)
    return nil if profile.blank?

    cache_key = subscription_billing_cache_key(profile)
    snapshot = Rails.cache.read(cache_key)
    return nil unless snapshot.is_a?(Hash)

    {
      payment_method: snapshot[:payment_method].presence || snapshot["payment_method"].presence,
      last_payment: snapshot[:last_payment].presence || snapshot["last_payment"].presence,
      history_rows: normalize_billing_history_rows(snapshot[:history_rows] || snapshot["history_rows"]),
      next_billing: snapshot[:next_billing].presence || snapshot["next_billing"].presence,
      next_charge: snapshot[:next_charge].presence || snapshot["next_charge"].presence
    }
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING CACHE READ ERROR: #{e.message}")
    nil
  end

  def write_subscription_billing_cache(profile:, payment_method:, last_payment:, history_rows:, next_billing: nil, next_charge: nil)
    return if profile.blank?

    payload = {
      payment_method: payment_method,
      last_payment: last_payment,
      history_rows: normalize_billing_history_rows(history_rows),
      next_billing: next_billing,
      next_charge: next_charge
    }

    Rails.cache.write(subscription_billing_cache_key(profile), payload, expires_in: 12.hours)
  rescue => e
    Rails.logger.warn("SUBSCRIPTION BILLING CACHE WRITE ERROR: #{e.message}")
  end

  def subscription_billing_cache_key(profile)
    identifier = profile.user_id.presence || profile.id
    "subscription:billing:snapshot:#{identifier}"
  end

  def normalize_billing_history_rows(rows)
    Array(rows).filter_map do |row|
      hash = row.is_a?(Hash) ? row.with_indifferent_access : nil
      next if hash.blank?

      status_raw = hash[:status_raw].to_s.downcase
      status_raw = hash[:status].to_s.downcase if status_raw.blank?
      status_kind = hash[:status_kind].presence || billing_history_status_kind(status_raw)
      next if status_kind.blank?

      {
        id: hash[:id].to_s,
        date: hash[:date].presence || t("subscription_page.not_available"),
        next_billing_label: hash[:next_billing_label].presence,
        amount: hash[:amount].presence || t("subscription_page.not_available"),
        status: status_kind,
        status_kind: status_kind,
        status_raw: status_raw,
        receipt_url: hash[:receipt_url].presence,
        invoice_id: hash[:invoice_id].presence,
        payment_method_label: hash[:payment_method_label].presence
      }
    end.first(10)
  end

  def currency_symbol_for(code)
    case code.to_s.upcase
    when "GEL" then "₾"
    when "EUR" then "€"
    when "GBP" then "£"
    when "JPY" then "¥"
    when "CHF" then "CHF "
    else "$"
    end
  end

  # ── Single-pass invoice analytics (all aggregates in one loop) ──
  def compute_invoice_analytics(user, profile, today)
    total_invoiced = 0.0
    total_outstanding = 0.0
    total_overdue_amount = 0.0
    total_paid_amount = 0.0
    total_sent_amount = 0.0
    collected_this_month = 0.0
    due_today_count = 0
    due_soon_count = 0
    due_soon_amount = 0.0
    overdue_count = 0
    month_start = today.beginning_of_month
    last_month_start = (today - 1.month).beginning_of_month
    last_month_end = month_start - 1.day

    # Avg days to pay tracking
    paid_durations = []

    # Due soon invoices detail list
    due_soon_invoices = []

    # Outstanding trend (this month vs last month)
    this_month_outstanding_created = 0.0
    last_month_outstanding_created = 0.0

    # Trend tracking (last month vs this month)
    this_month_revenue = 0.0
    last_month_revenue = 0.0
    this_month_outstanding = 0.0
    last_month_outstanding_snapshot = 0.0
    this_month_invoices = 0
    last_month_invoices = 0
    this_month_new_clients = Set.new
    last_month_new_clients = Set.new

    status_counts = { draft: 0, sent: 0, paid: 0, overdue: 0 }
    aging = { due_today: 0, overdue_1_7: 0, overdue_7_30: 0, overdue_30_plus: 0 }
    aging_invoices = { due_today: [], overdue_1_7: [], overdue_7_30: [], overdue_30_plus: [] }
    aging_amounts = { due_today: 0.0, overdue_1_7: 0.0, overdue_7_30: 0.0, overdue_30_plus: 0.0 }

    # Client tracking
    client_data = Hash.new { |h, k| h[k] = { total: 0.0, outstanding: 0.0, count: 0, overdue_count: 0, last_at: nil } }
    all_client_first_seen = {}

    user.logs.kept.find_each do |log|
      totals = helpers.calculate_log_totals(log, profile)
      amount = totals[:total_due].to_f
      total_invoiced += amount

      effective_status = log.current_status
      status_counts[effective_status.to_sym] = (status_counts[effective_status.to_sym] || 0) + 1

      parsed_due = log.parsed_due_date
      created = log.created_at

      # Trend: count invoices per month
      if created >= month_start.to_time
        this_month_invoices += 1
      elsif created >= last_month_start.to_time && created < month_start.to_time
        last_month_invoices += 1
      end

      case effective_status
      when "paid"
        total_paid_amount += amount
        total_sent_amount += amount
        # Avg days to pay
        if log.paid_at && log.created_at
          days_took = ((log.paid_at - log.created_at) / 1.day).round(1)
          paid_durations << days_took if days_took >= 0
        end
        if log.paid_at && log.paid_at >= month_start.to_time
          collected_this_month += amount
          this_month_revenue += amount
        elsif log.paid_at.nil? && log.updated_at >= month_start.to_time
          collected_this_month += amount
          this_month_revenue += amount
        end
        if log.paid_at && log.paid_at >= last_month_start.to_time && log.paid_at < month_start.to_time
          last_month_revenue += amount
        end
      when "overdue"
        total_outstanding += amount
        total_overdue_amount += amount
        total_sent_amount += amount
        overdue_count += 1
        _inv_detail = { id: log.id, client: log.client.to_s.strip.presence || "—", amount: amount.round(2), days: 0, due_date: parsed_due&.strftime("%b %d, %Y") || "—", display_number: log.display_number }
        if parsed_due
          days_overdue = (today - parsed_due).to_i
          _inv_detail[:days] = days_overdue
          if days_overdue == 0
            aging[:due_today] += 1
            aging_invoices[:due_today] << _inv_detail
            aging_amounts[:due_today] += amount
          elsif days_overdue <= 7
            aging[:overdue_1_7] += 1
            aging_invoices[:overdue_1_7] << _inv_detail
            aging_amounts[:overdue_1_7] += amount
          elsif days_overdue <= 30
            aging[:overdue_7_30] += 1
            aging_invoices[:overdue_7_30] << _inv_detail
            aging_amounts[:overdue_7_30] += amount
          else
            aging[:overdue_30_plus] += 1
            aging_invoices[:overdue_30_plus] << _inv_detail
            aging_amounts[:overdue_30_plus] += amount
          end
        else
          aging[:overdue_30_plus] += 1
          _inv_detail[:days] = 999
          aging_invoices[:overdue_30_plus] << _inv_detail
          aging_amounts[:overdue_30_plus] += amount
        end
      when "sent"
        total_outstanding += amount
        total_sent_amount += amount
        # Outstanding trend
        if created >= month_start.to_time
          this_month_outstanding_created += amount
        elsif created >= last_month_start.to_time && created < month_start.to_time
          last_month_outstanding_created += amount
        end
        if parsed_due
          days_until = (parsed_due - today).to_i
          _inv_detail = { id: log.id, client: log.client.to_s.strip.presence || "—", amount: amount.round(2), days: days_until.abs, due_date: parsed_due.strftime("%b %d, %Y"), display_number: log.display_number }
          if days_until < 0
            total_overdue_amount += amount
            overdue_count += 1
            days_overdue = -days_until
            if days_overdue <= 7
              aging[:overdue_1_7] += 1
              aging_invoices[:overdue_1_7] << _inv_detail
              aging_amounts[:overdue_1_7] += amount
            elsif days_overdue <= 30
              aging[:overdue_7_30] += 1
              aging_invoices[:overdue_7_30] << _inv_detail
              aging_amounts[:overdue_7_30] += amount
            else
              aging[:overdue_30_plus] += 1
              aging_invoices[:overdue_30_plus] << _inv_detail
              aging_amounts[:overdue_30_plus] += amount
            end
          elsif days_until == 0
            due_today_count += 1
            aging[:due_today] += 1
            aging_invoices[:due_today] << _inv_detail
            aging_amounts[:due_today] += amount
          elsif days_until <= 7
            due_soon_count += 1
            due_soon_amount += amount
            due_soon_invoices << { id: log.id, client: log.client.to_s.strip.presence || "—", amount: amount.round(2), days_left: days_until, due_date: parsed_due.strftime("%b %d, %Y"), display_number: log.display_number }
          end
        end
      when "draft"
        total_outstanding += amount
        # Outstanding trend
        if created >= month_start.to_time
          this_month_outstanding_created += amount
        elsif created >= last_month_start.to_time && created < month_start.to_time
          last_month_outstanding_created += amount
        end
        if parsed_due
          days_until = (parsed_due - today).to_i
          _inv_detail = { id: log.id, client: log.client.to_s.strip.presence || "—", amount: amount.round(2), days: days_until.abs, due_date: parsed_due.strftime("%b %d, %Y"), display_number: log.display_number }
          if days_until < 0
            total_overdue_amount += amount
            overdue_count += 1
            days_overdue = -days_until
            if days_overdue <= 7
              aging[:overdue_1_7] += 1
              aging_invoices[:overdue_1_7] << _inv_detail
              aging_amounts[:overdue_1_7] += amount
            elsif days_overdue <= 30
              aging[:overdue_7_30] += 1
              aging_invoices[:overdue_7_30] << _inv_detail
              aging_amounts[:overdue_7_30] += amount
            else
              aging[:overdue_30_plus] += 1
              aging_invoices[:overdue_30_plus] << _inv_detail
              aging_amounts[:overdue_30_plus] += amount
            end
          elsif days_until == 0
            due_today_count += 1
            aging[:due_today] += 1
            aging_invoices[:due_today] << _inv_detail
            aging_amounts[:due_today] += amount
          elsif days_until <= 7
            due_soon_count += 1
            due_soon_amount += amount
            due_soon_invoices << { id: log.id, client: log.client.to_s.strip.presence || "—", amount: amount.round(2), days_left: days_until, due_date: parsed_due.strftime("%b %d, %Y"), display_number: log.display_number }
          end
        end
      end

      # Client tracking
      cname = log.client.to_s.strip
      if cname.present?
        client_data[cname][:total] += amount
        client_data[cname][:count] += 1
        client_data[cname][:outstanding] += amount unless effective_status == "paid"
        client_data[cname][:overdue_count] += 1 if effective_status == "overdue" || (parsed_due && (parsed_due - today).to_i < 0 && effective_status != "paid")
        log_date = created
        if client_data[cname][:last_at].nil? || log_date > client_data[cname][:last_at]
          client_data[cname][:last_at] = log_date
        end
        first_seen = all_client_first_seen[cname]
        if first_seen.nil? || log_date < first_seen
          all_client_first_seen[cname] = log_date
        end
        # Track new clients per month for trends
        if created >= month_start.to_time && all_client_first_seen[cname] && all_client_first_seen[cname] >= month_start.to_time
          this_month_new_clients << cname
        end
      end
    rescue => e
      Rails.logger.warn("Analytics compute error for log #{log.id}: #{e.message}")
    end

    # Recount new clients (first_seen accuracy after full loop)
    new_clients_month_count = all_client_first_seen.count { |_, first| first >= month_start.to_time }
    last_month_new_clients_count = all_client_first_seen.count { |_, first| first >= last_month_start.to_time && first < month_start.to_time }

    # ── Financial Health Score ──
    health_score = total_invoiced > 0 ? ((total_paid_amount / total_invoiced) * 100).round(0) : 100
    health_level = if health_score >= 90 then "healthy"
                   elsif health_score >= 60 then "risk"
                   else "critical"
                   end

    # ── Collection Rate ──
    collection_rate = total_sent_amount > 0 ? ((total_paid_amount / total_sent_amount) * 100).round(0) : 100

    # ── Outstanding Ratio ──
    outstanding_ratio = total_invoiced > 0 ? ((total_outstanding / total_invoiced) * 100).round(0) : 0

    # ── Revenue Projection ──
    days_elapsed = [today.day, 1].max
    days_in_month = today.end_of_month.day
    projected_revenue = ((collected_this_month / days_elapsed) * days_in_month).round(2)

    # ── Trend Indicators (% change vs last month) ──
    revenue_trend = last_month_revenue > 0 ? (((this_month_revenue - last_month_revenue) / last_month_revenue) * 100).round(0) : nil
    invoices_trend = last_month_invoices > 0 ? (((this_month_invoices - last_month_invoices).to_f / last_month_invoices) * 100).round(0) : nil
    new_clients_trend = last_month_new_clients_count > 0 ? (((new_clients_month_count - last_month_new_clients_count).to_f / last_month_new_clients_count) * 100).round(0) : nil

    # ── Client Risk Badges ──
    top_revenue_threshold = client_data.any? ? client_data.values.map { |d| d[:total] }.sort.last(3).first : 0
    client_insights = client_data.map do |name, data|
      badges = []
      badges << "top_client" if data[:total] >= top_revenue_threshold && top_revenue_threshold > 0
      badges << "high_outstanding" if data[:outstanding] > 0 && data[:outstanding] > (data[:total] * 0.5)
      badges << "frequently_overdue" if data[:overdue_count] >= 2
      { name: name, total: data[:total].round(2), outstanding: data[:outstanding].round(2),
        count: data[:count], overdue_count: data[:overdue_count], last_at: data[:last_at], badges: badges }
    end.sort_by { |c| -c[:total] }.first(10)

    repeat_clients = client_data.count { |_, d| d[:count] > 1 }

    total_count = status_counts.values.sum
    avg_invoice = total_count > 0 ? (total_invoiced / total_count).round(2) : 0.0

    # ── Avg Days to Pay ──
    avg_days_to_pay = paid_durations.any? ? (paid_durations.sum / paid_durations.size).round(1) : nil

    # ── Sort due_soon by urgency (fewest days left first, then highest amount) ──
    due_soon_invoices.sort_by! { |inv| [inv[:days_left], -inv[:amount]] }

    # ── Top Client Revenue Share ──
    top_client_share = 0
    top_client_name = nil
    if client_data.any? && total_invoiced > 0
      top = client_data.max_by { |_, d| d[:total] }
      if top
        top_client_name = top[0]
        top_client_share = ((top[1][:total] / total_invoiced) * 100).round(0)
      end
    end

    # ── Outstanding Trend (this month vs last month new outstanding) ──
    outstanding_trend = last_month_outstanding_created > 0 ? (((this_month_outstanding_created - last_month_outstanding_created) / last_month_outstanding_created) * 100).round(0) : nil

    {
      total_invoiced: total_invoiced.round(2),
      total_outstanding: total_outstanding.round(2),
      total_overdue_amount: total_overdue_amount.round(2),
      total_paid_amount: total_paid_amount.round(2),
      total_sent_amount: total_sent_amount.round(2),
      collected_this_month: collected_this_month.round(2),
      status_counts: status_counts,
      aging: aging,
      aging_invoices: aging_invoices,
      aging_amounts: aging_amounts,
      due_today_count: due_today_count,
      due_soon_count: due_soon_count,
      due_soon_amount: due_soon_amount.round(2),
      overdue_count: overdue_count,
      client_insights: client_insights,
      repeat_clients: repeat_clients,
      new_clients_month: new_clients_month_count,
      avg_invoice: avg_invoice,
      health_score: health_score,
      health_level: health_level,
      collection_rate: collection_rate,
      outstanding_ratio: outstanding_ratio,
      projected_revenue: projected_revenue,
      revenue_trend: revenue_trend,
      invoices_trend: invoices_trend,
      new_clients_trend: new_clients_trend,
      this_month_invoices: this_month_invoices,
      last_month_invoices: last_month_invoices,
      avg_days_to_pay: avg_days_to_pay,
      due_soon_invoices: due_soon_invoices,
      top_client_share: top_client_share,
      top_client_name: top_client_name,
      outstanding_trend: outstanding_trend,
      cached_at: Time.current
    }
  end

  # ── Alerts builder ──
  def build_alerts(data, profile)
    alerts = []
    currency_symbol = case (profile.currency.presence || "USD")
                      when "GEL" then "₾"
                      when "EUR" then "€"
                      when "GBP" then "£"
                      else "$"
                      end
    fmt = ->(v) { "#{currency_symbol}#{ActionController::Base.helpers.number_with_delimiter(v.round(2))}" }

    if data[:overdue_count] > 0
      alerts << { type: "danger", icon: "alert-triangle",
                  title: t("analytics_page.alert_overdue_title", count: data[:overdue_count]),
                  desc: t("analytics_page.alert_overdue_desc", amount: fmt.call(data[:total_overdue_amount])),
                  action: "overdue" }
    end

    if data[:due_today_count] > 0
      alerts << { type: "warning", icon: "clock",
                  title: t("analytics_page.alert_due_today_title", count: data[:due_today_count]),
                  desc: t("analytics_page.alert_due_today_desc"),
                  action: "due_today" }
    end

    if data[:due_soon_count] > 0
      alerts << { type: "info", icon: "calendar",
                  title: t("analytics_page.alert_due_soon_title", count: data[:due_soon_count]),
                  desc: t("analytics_page.alert_due_soon_desc", amount: fmt.call(data[:due_soon_amount])),
                  action: "due_soon" }
    end

    threshold = profile.try(:analytics_alert_threshold).to_f
    threshold = 5000 if threshold <= 0
    if data[:total_outstanding] > threshold
      alerts << { type: "warning", icon: "dollar-sign",
                  title: t("analytics_page.alert_high_outstanding_title"),
                  desc: t("analytics_page.alert_high_outstanding_desc", amount: fmt.call(data[:total_outstanding])),
                  action: "unpaid" }
    end

    # Health warning
    if data[:health_level] == "critical"
      alerts << { type: "danger", icon: "alert-triangle",
                  title: t("analytics_page.alert_health_critical_title"),
                  desc: t("analytics_page.alert_health_critical_desc", score: data[:health_score]) }
    end

    alerts
  end

  # ── Time-series helpers for new metrics ──
  def outstanding_time_series(user_id, period)
    range = case period
            when "7d" then 7.days.ago..Time.current
            when "30d" then 30.days.ago..Time.current
            when "12m" then 12.months.ago..Time.current
            else 30.days.ago..Time.current
            end
    trunc = period == "12m" ? "month" : "day"

    Log.where(user_id: user_id).kept
      .where(status: %w[draft sent overdue])
      .where(created_at: range)
      .group("DATE_TRUNC('#{trunc}', created_at)")
      .sum(:cached_total_due)
      .transform_keys { |k| k.strftime(trunc == "month" ? "%Y-%m" : "%Y-%m-%d") }
      .transform_values { |v| v.to_f.round(2) }
  end

  def collected_time_series(user_id, period)
    range = case period
            when "7d" then 7.days.ago..Time.current
            when "30d" then 30.days.ago..Time.current
            when "12m" then 12.months.ago..Time.current
            else 30.days.ago..Time.current
            end
    trunc = period == "12m" ? "month" : "day"

    Log.where(user_id: user_id).kept
      .where(status: "paid")
      .where(paid_at: range)
      .group("DATE_TRUNC('#{trunc}', COALESCE(paid_at, updated_at))")
      .sum(:cached_total_due)
      .transform_keys { |k| k.strftime(trunc == "month" ? "%Y-%m" : "%Y-%m-%d") }
      .transform_values { |v| v.to_f.round(2) }
  end

  def fill_time_series(data, period)
    filled = {}
    case period
    when "7d"
      (0..6).each do |i|
        key = (Time.current - (6 - i).days).strftime("%Y-%m-%d")
        filled[key] = data[key] || 0
      end
    when "30d"
      (0..29).each do |i|
        key = (Time.current - (29 - i).days).strftime("%Y-%m-%d")
        filled[key] = data[key] || 0
      end
    when "12m"
      (0..11).each do |i|
        key = (Time.current - (11 - i).months).beginning_of_month.strftime("%Y-%m")
        filled[key] = data[key] || 0
      end
    else
      filled = data
    end
    filled
  end

  def populate_analytics_demo_data
    ka = I18n.locale.to_s == "ka"

    # Locale-aware dummy client names
    clients_en = ["Acme Corp", "BuildRight LLC", "Nova Studio", "Peak Solutions", "Bright Media"]
    clients_ka = ["აქმე კორპ", "ბილდრაიტი", "ნოვა სტუდია", "პიქ სოლუშენსი", "ბრაიტ მედია"]
    client_names = ka ? clients_ka : clients_en

    @currency_symbol   = "₾"
    @total_invoiced    = 18_450.0
    @total_outstanding = 4_200.0
    @total_overdue_amt = 1_840.0
    @total_paid_amt    = 14_250.0
    @collected_this_month = 3_100.0
    @projected_revenue = 5_800.0
    @avg_invoice       = 1_230.0
    @health_score      = 74
    @health_level      = "risk"
    @collection_rate   = 77
    @outstanding_ratio = 23
    @revenue_trend     = 24
    @invoices_trend    = 12
    @new_clients_trend = nil
    @outstanding_trend = -8
    @avg_days_to_pay   = 18
    @overdue_count     = 3
    @due_soon_count    = 2
    @due_soon_amount   = 2_600.0
    @due_today_count   = 1
    @repeat_clients    = 4
    @new_clients_month = 2
    @top_client_share  = nil
    @top_client_name   = nil
    @analytics_cached_at = nil

    @status_counts = { draft: 2, sent: 5, paid: 14, overdue: 3 }

    @aging = { due_today: 1, overdue_1_7: 1, overdue_7_30: 2, overdue_30_plus: 0 }
    @aging_invoices = {}
    @aging_amounts  = { due_today: 840.0, overdue_1_7: 1_000.0, overdue_7_30: 840.0, overdue_30_plus: 0.0 }

    @due_soon_invoices = [
      { days_left: 2, client: client_names[0], display_number: "0042", due_date: (Date.today + 2).strftime("%d/%m/%Y"), amount: 1_500.0 },
      { days_left: 5, client: client_names[2], display_number: "0041", due_date: (Date.today + 5).strftime("%d/%m/%Y"), amount: 1_100.0 }
    ]

    @client_insights = client_names.first(4).each_with_index.map do |name, i|
      totals    = [6_200.0, 4_800.0, 3_900.0, 2_100.0]
      outs      = [0.0, 1_200.0, 0.0, 840.0]
      counts    = [8, 6, 5, 3]
      last_ats  = [3.days.ago, 10.days.ago, 20.days.ago, 45.days.ago]
      badges    = [["top_client"], [], ["repeat"], []]
      { name: name, total: totals[i], outstanding: outs[i], count: counts[i],
        last_at: last_ats[i], badges: badges[i] }
    end

    @alerts = []
    @overview = { active_clients: 5, total_invoices: 24 }
    @tracking_counts = { exports: 12, recordings_started: 38 }
  end

  private

  # ── Auto-upgrade AI clarifications into 4 ordered groups:
  #    1. Ambiguity (item type/description)  →  item_input_list with text inputs
  #    2. Prices & quantities                →  item_input_list with qty/price/toggle
  #    3. Per-item discounts                 →  item_input_list with amount + type toggle
  #    4. Tax rates                          →  tax_management widget (slider per item)
  #    Priority order: category → name → qty/price → discount → tax ──
  def auto_upgrade_clarifications!(data, language)
    clars = data["clarifications"]
    return unless clars.is_a?(Array) && clars.any?

    ui_ka = language.to_s.start_with?("ka")
    default_billing = begin; @profile&.billing_mode || "hourly"; rescue; "hourly"; end
    cat_prefixes = %w[labor materials expenses fees]

    # ── Detection patterns ──
    price_re   = /ღირს|ფასი|ფასად|price|cost|charge/i
    qty_re     = /რაოდენობ|quantity|რამდენ/i
    disc_re    = /ფასდაკლება|discount/i
    tax_re     = /დღგ|vat|tax.*rate|tax.*განაკვეთ/i
    ambig_re   = /სახის|რისი|what kind|what type|describe|აღწერ/i
    exclude_re = /ფასდაკლება|discount|დღგ|vat|tax|გადასახ/i
    labor_re   = /შეკეთება|რემონტი|მონტაჟი|ინსტალაცია|repair|install|service|maintenance|fix|labor|work|მომსახურება|წმენდა|cleaning|painting|შეღებვა/i

    # ── Section items for name matching & per-item widgets ──
    section_items = (data["sections"] || []).flat_map do |s|
      cat = s["type"].to_s
      (s["items"] || []).map { |i| { desc: i["desc"].to_s.strip, category: cat } }
    end

    # ── Name resolution: prefer AI-provided item_name, fallback to regex cleaning ──
    # resolve_name: use c["item_name"] if AI provided it, otherwise fall back to clean_name
    resolve_name = lambda do |clar_hash, fallback_raw|
      ai_name = clar_hash.is_a?(Hash) ? clar_hash["item_name"].to_s.strip : ""
      return ai_name if ai_name.present? && section_items.any? { |s| s[:desc].downcase == ai_name.downcase }
      clean_name.call(fallback_raw)
    end

    # clean_name: FALLBACK regex extraction (only used when AI doesn't provide item_name)
    clean_name = lambda do |raw|
      name = raw.to_s.strip
      return "Item" if name.blank? || name.match?(/\A[\d.,\s]+\z/)
      # Strip full question patterns: "რა ფასად გსურთ X-ის დამატება?", "რა ღირს X?", etc.
      name = name.gsub(/[?？]+\s*$/, "")                             # trailing ?
                  .gsub(/^რა\s+ფასად\s+გსურთ\s+/i, "")              # რა ფასად გსურთ ...
                  .gsub(/^რა\s+ღირს\s+/i, "")                       # რა ღირს ...
                  .gsub(/^რამდენი?\s+/i, "")                         # რამდენი ...
                  .gsub(/^რა\s+სახის\s+/i, "")                      # რა სახის ...
                  .gsub(/^გსურთ\s+/i, "")                           # გსურთ ...
                  .gsub(/\s+დამატება$/i, "")                        # ... დამატება
                  .gsub(/\s+შეცვლა$/i, "")                         # ... შეცვლა
                  .gsub(/\s+გსურთ$/i, "")                           # ... გსურთ (trailing)
                  .gsub(/\(.*?\)/, "")                               # (...) parenthetical
                  .gsub(/\s+/, " ").strip
      # Strip Georgian genitive suffix -ის if it makes a match
      if name.end_with?("ის") && name.length > 3
        stem = name[0..-3]
        si = section_items.find { |s| s[:desc].downcase == stem.downcase }
        name = si[:desc] if si
      elsif name.end_with?("ს") && name.length > 2
        stem = name[0..-2]
        si = section_items.find { |s| s[:desc].downcase == stem.downcase }
        name = si[:desc] if si
      end
      return "Item" if name.blank?
      norm = name.downcase
      match = section_items.find do |si|
        d = si[:desc].downcase
        d == norm || norm.include?(d) || d.include?(norm)
      end
      match ? match[:desc] : name
    end

    # ── Categorize every clarification ──
    absorbed = Set.new
    ambig_list = []    # { clar:, name: }
    price_list = []    # original clar objects
    qty_list   = []
    disc_list  = []
    tax_list   = []
    existing_iil = nil # AI-generated item_input_list (if any)

    clars.each do |c|
      next unless c.is_a?(Hash)
      q = c["question"].to_s
      f = c["field"].to_s
      t = c["type"].to_s

      # AI already returned item_input_list → absorb it, clean names later
      if t == "item_input_list"
        existing_iil ||= c
        absorbed << c.object_id
        next
      end

      # Ambiguity: "რა სახის?", "რისი?", "what kind?" — NOT price/qty/disc/tax
      if q.match?(ambig_re) && !q.match?(price_re) && !q.match?(qty_re) && !q.match?(disc_re) && !q.match?(tax_re)
        absorbed << c.object_id
        name = resolve_name.call(c, c["guess"].to_s.presence || q.gsub(/[?？]/, "").gsub(ambig_re, "").gsub(/^რა\s+/i, "").strip)
        ambig_list << { clar: c, name: name }
        next
      end

      # Price question (text about item cost, NOT discount/tax)
      if t == "text" && q.match?(price_re) && !q.match?(exclude_re) && !f.match?(/discount|tax/i)
        absorbed << c.object_id
        price_list << c
        next
      end

      # Quantity question
      if t == "text" && q.match?(qty_re) && !q.match?(exclude_re)
        absorbed << c.object_id
        qty_list << c
        next
      end

      # Discount question (any type: text, choice, multi_choice)
      if q.match?(disc_re) || f.match?(/discount/i)
        absorbed << c.object_id
        disc_list << c
        next
      end

      # Tax question
      if q.match?(tax_re) || f.match?(/tax_rate|vat/i)
        absorbed << c.object_id
        tax_list << c
        next
      end
    end

    new_clars = []

    # ══════════════════════════════════════════════════════════════════
    # GROUP 1: AMBIGUITY — item type/description clarification (FIRST)
    # ══════════════════════════════════════════════════════════════════
    if ambig_list.length >= 2
      q_text = ui_ka ? "გთხოვთ დააზუსტოთ ინფორმაცია:" : "Please clarify:"
      items = ambig_list.map do |a|
        label = a[:clar]["question"].to_s.gsub(/[?？]\s*$/, "").strip
        { "name" => a[:name], "inputs" => [{ "key" => "description", "label" => label, "type" => "text" }] }
      end
      new_clars << { "type" => "item_input_list", "field" => "item_clarification", "question" => q_text, "items" => items }
    elsif ambig_list.length == 1
      c = ambig_list.first[:clar]
      c["_original_name"] = ambig_list.first[:name]
      new_clars << c
    end

    # ══════════════════════════════════════════════════════════════════
    # GROUP 2: PRICES & QUANTITIES — merged item_input_list
    # ══════════════════════════════════════════════════════════════════
    price_lbl = ui_ka ? "ფასი" : "Price"
    qty_lbl   = ui_ka ? "რაოდენობა" : "Qty"
    price_q   = ui_ka ? "შეავსეთ საჭირო ინფორმაცია:" : "Fill in the details:"

    if existing_iil
      # Clean names + ensure inputs/toggles in AI-generated item_input_list
      (existing_iil["items"] || []).each do |item|
        item["name"] = resolve_name.call(item, item["name"])
        cat = item["category"].to_s
        # Match category from section items if missing, fallback to keyword detection
        if cat.blank?
          si = section_items.find { |s| s[:desc].downcase == item["name"].downcase }
          cat = si[:category] if si
          cat = "labor" if cat.blank? && item["name"].to_s.match?(labor_re)
          item["category"] = cat
        end
        # Ensure materials have qty input
        has_qty = (item["inputs"] || []).any? { |inp| inp["key"] == "qty" }
        if cat == "materials" && !has_qty
          (item["inputs"] ||= []).unshift({ "key" => "qty", "label" => qty_lbl, "type" => "number", "value" => 1 })
        end
        # Ensure labor has billing_mode toggle with profile default
        if cat == "labor" && item["toggle"].nil?
          item["toggle"] = { "key" => "billing_mode", "options" => ["fixed", "hourly"], "default" => default_billing }
        elsif item["toggle"] && item["toggle"]["key"] == "billing_mode" && item["toggle"]["default"].blank?
          item["toggle"]["default"] = default_billing
        end
      end
      # Absorb any standalone qty questions (already in the card)
      qty_list.each { |qc| absorbed << qc.object_id }
      price_list.each { |pc| absorbed << pc.object_id }
      new_clars << existing_iil

    elsif price_list.length >= 2
      # Build item_input_list from individual text questions
      merged_names = Set.new
      items = price_list.map do |pc|
        item_name = resolve_name.call(pc, pc["guess"].to_s.presence || pc["question"])
        merged_names << item_name.downcase
        field_cat = pc["field"].to_s.split(".").first
        category = cat_prefixes.include?(field_cat) ? field_cat : nil
        category ||= section_items.find { |s| s[:desc].downcase == item_name.downcase }&.dig(:category)
        category ||= "labor" if item_name.match?(labor_re)

        # Find matching qty question
        mq = qty_list.find do |qc|
          qn = resolve_name.call(qc, qc["guess"].to_s.presence || qc["question"])
          qn.downcase == item_name.downcase
        end
        absorbed << mq.object_id if mq

        inputs = []
        inputs << { "key" => "qty", "label" => qty_lbl, "type" => "number", "value" => 1 } if mq || category == "materials"
        inputs << { "key" => "price", "label" => price_lbl, "type" => "number" }
        toggle = category == "labor" ? { "key" => "billing_mode", "options" => ["fixed", "hourly"], "default" => default_billing } : nil
        { "name" => item_name, "category" => category, "inputs" => inputs, "toggle" => toggle }
      end
      # Absorb leftover qty questions for items already in card
      qty_list.each do |qc|
        next if absorbed.include?(qc.object_id)
        qn = resolve_name.call(qc, qc["guess"].to_s.presence || qc["question"])
        absorbed << qc.object_id if merged_names.include?(qn.downcase)
      end
      new_clars << { "type" => "item_input_list", "field" => "item_prices", "question" => price_q, "items" => items }
    end

    # ══════════════════════════════════════════════════════════════════
    # GROUP 3: PER-ITEM DISCOUNTS — amount + fixed/% toggle per item
    # Use section_items first; if empty, fall back to item names from group 2 price card
    # ══════════════════════════════════════════════════════════════════
    if disc_list.any?
      disc_q   = ui_ka ? "შეიყვანეთ ფასდაკლების ინფორმაცია:" : "Enter discount details:"
      amt_lbl  = ui_ka ? "თანხა" : "Amount"

      # Collect item names: prefer section_items, fall back to price card items
      disc_item_names = section_items.map { |si| si[:desc] }
      if disc_item_names.empty?
        # Extract from the price card we just built in group 2
        price_card = new_clars.find { |c| c["field"] == "item_prices" || (c["type"] == "item_input_list" && c["field"] != "item_clarification") }
        if price_card && price_card["items"]
          disc_item_names = price_card["items"].map { |i| i["name"] }
        end
      end

      if disc_item_names.any?
        items = disc_item_names.map do |item_name|
          {
            "name" => item_name,
            "inputs" => [{ "key" => "amount", "label" => amt_lbl, "type" => "number" }],
            "toggle" => { "key" => "discount_type", "options" => ["fixed", "percentage"], "default" => "percentage" }
          }
        end
        new_clars << { "type" => "item_input_list", "field" => "discount_setup", "question" => disc_q, "items" => items }
      else
        # Absolute fallback: single generic discount entry
        disc_label = ui_ka ? "ფასდაკლება" : "Discount"
        new_clars << {
          "type" => "item_input_list", "field" => "discount_setup", "question" => disc_q,
          "items" => [{ "name" => disc_label, "inputs" => [{ "key" => "amount", "label" => amt_lbl, "type" => "number" }],
                         "toggle" => { "key" => "discount_type", "options" => ["fixed", "percentage"], "default" => "percentage" } }]
        }
      end
    end

    # ══════════════════════════════════════════════════════════════════
    # GROUP 4: TAX — use existing tax_management widget (sliders)
    # ══════════════════════════════════════════════════════════════════
    if tax_list.any?
      tax_q = ui_ka ? "დააყენეთ დღგ-ს განაკვეთი:" : "Set tax rates:"
      new_clars << { "type" => "tax_management", "field" => "tax_rate", "question" => tax_q }
    end

    # ── Apply: remove absorbed originals, prepend ordered groups ──
    clars.reject! { |c| absorbed.include?(c.object_id) }
    data["clarifications"] = new_clars + clars
    Rails.logger.info "AUTO-UPGRADE: ambig=#{ambig_list.length} price=#{price_list.length} qty=#{qty_list.length} disc=#{disc_list.length} tax=#{tax_list.length} → #{new_clars.length} widgets + #{clars.length} remaining"
  end

  # Normalize a client name for matching: strip legal forms, special quotes, downcase
  def normalize_client_name(name)
    n = name.to_s.dup
    # Strip Georgian/international legal forms
    n.gsub!(/\b(შპს|შ\.პ\.ს\.|ს\.ს\.|სს|Ltd\.?|LLC|Inc\.?|Corp\.?|GmbH|ООО|ИП|ОАО|ЗАО|S\.?A\.?|S\.?L\.?|PLC|Pty|Co\.?)\b/i, '')
    # Strip special quotes: Georgian „", «», "", standard ""
    n.gsub!(/[„""«»"\u201C\u201D\u201E\u00AB\u00BB]/, '')
    n.strip.gsub(/\s+/, ' ').downcase
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
      :hours_per_workday,
      :tax_rate,
      :tax_scope,
      :payment_instructions,
      :note,
      :billing_mode,
      :currency,
      :invoice_style,
      :discount_tax_rule,
      :remove_logo,
      :logo,
      :accent_color,
      :system_language,
      :document_language,
      :transcription_language,
      :analytics_alert_threshold
    )
  end
end
