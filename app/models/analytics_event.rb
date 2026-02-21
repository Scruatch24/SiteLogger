class AnalyticsEvent < ApplicationRecord
  belongs_to :user

  # Event types
  VOICE_RECORDING = "voice_recording"
  INVOICE_CREATED = "invoice_created"
  TRANSCRIPTION_SUCCESS = "transcription_success"
  TRANSCRIPTION_FAILURE = "transcription_failure"
  VOICE_PROCESSING = "voice_processing"
  INVOICE_EDITED = "invoice_edited"

  EVENT_TYPES = [
    VOICE_RECORDING,
    INVOICE_CREATED,
    TRANSCRIPTION_SUCCESS,
    TRANSCRIPTION_FAILURE,
    VOICE_PROCESSING,
    INVOICE_EDITED
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :user_id, presence: true

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :of_type, ->(type) { where(event_type: type) }
  scope :since, ->(time) { where("created_at >= ?", time) }
  scope :in_range, ->(from, to) { where(created_at: from..to) }

  # ── Aggregation helpers ──

  def self.overview_for(user_id)
    logs = Log.where(user_id: user_id).kept
    events = where(user_id: user_id)

    total_invoices = logs.count
    this_month_invoices = logs.where("created_at >= ?", Time.current.beginning_of_month).count

    voice_recordings = events.of_type(VOICE_RECORDING).count
    transcription_successes = events.of_type(TRANSCRIPTION_SUCCESS).count
    transcription_failures = events.of_type(TRANSCRIPTION_FAILURE).count
    total_transcriptions = transcription_successes + transcription_failures
    success_rate = total_transcriptions > 0 ? ((transcription_successes.to_f / total_transcriptions) * 100).round(1) : 100.0

    # Estimated time saved: ~3 min per voice invoice vs ~12 min manual
    avg_time_saved_per_invoice_seconds = 540 # 9 minutes saved per voice invoice
    time_saved_seconds = voice_recordings * avg_time_saved_per_invoice_seconds

    {
      total_invoices: total_invoices,
      this_month_invoices: this_month_invoices,
      voice_recordings: voice_recordings,
      success_rate: success_rate,
      time_saved_seconds: time_saved_seconds,
      total_transcriptions: total_transcriptions,
      transcription_failures: transcription_failures
    }
  end

  def self.revenue_for(user_id, currency: nil)
    events = where(user_id: user_id).of_type(INVOICE_CREATED).where.not(amount: nil)
    events = events.where(currency: currency) if currency.present?

    total_amount = events.sum(:amount).to_f
    count = events.count
    avg_amount = count > 0 ? (total_amount / count).round(2) : 0.0

    # Monthly trend (last 12 months)
    monthly = events
      .where("created_at >= ?", 12.months.ago.beginning_of_month)
      .group("DATE_TRUNC('month', created_at)")
      .sum(:amount)
      .transform_keys { |k| k.strftime("%Y-%m") }

    {
      total_amount: total_amount,
      invoice_count: count,
      avg_amount: avg_amount,
      monthly_trend: monthly
    }
  end

  def self.voice_performance_for(user_id)
    events = where(user_id: user_id)

    processing_events = events.of_type(VOICE_PROCESSING)
    avg_processing_time = processing_events.average(:duration_seconds).to_f.round(2)

    edit_events = events.of_type(INVOICE_EDITED)
    voice_events = events.of_type(VOICE_RECORDING)
    edit_rate = voice_events.count > 0 ? ((edit_events.count.to_f / voice_events.count) * 100).round(1) : 0.0

    {
      avg_processing_time: avg_processing_time,
      edit_rate: edit_rate,
      total_edits: edit_events.count,
      failed_attempts: events.of_type(TRANSCRIPTION_FAILURE).count
    }
  end

  def self.time_series_for(user_id, period: "30d", metric: "invoices")
    range = case period
            when "7d" then 7.days.ago..Time.current
            when "30d" then 30.days.ago..Time.current
            when "12m" then 12.months.ago..Time.current
            else 30.days.ago..Time.current
            end

    trunc = period == "12m" ? "month" : "day"

    case metric
    when "invoices"
      Log.where(user_id: user_id).kept
        .where(created_at: range)
        .group("DATE_TRUNC('#{trunc}', created_at)")
        .count
        .transform_keys { |k| k.strftime(trunc == "month" ? "%Y-%m" : "%Y-%m-%d") }
    when "voice"
      where(user_id: user_id).of_type(VOICE_RECORDING)
        .where(created_at: range)
        .group("DATE_TRUNC('#{trunc}', created_at)")
        .count
        .transform_keys { |k| k.strftime(trunc == "month" ? "%Y-%m" : "%Y-%m-%d") }
    when "revenue"
      where(user_id: user_id).of_type(INVOICE_CREATED)
        .where(created_at: range)
        .where.not(amount: nil)
        .group("DATE_TRUNC('#{trunc}', created_at)")
        .sum(:amount)
        .transform_keys { |k| k.strftime(trunc == "month" ? "%Y-%m" : "%Y-%m-%d") }
    else
      {}
    end
  end

  def self.productivity_for(user_id)
    events = where(user_id: user_id)
    voice_count = events.of_type(VOICE_RECORDING).count
    processing = events.of_type(VOICE_PROCESSING)

    avg_creation_time = processing.average(:duration_seconds).to_f.round(1)
    manual_estimate_seconds = 720 # 12 min manual
    voice_estimate_seconds = avg_creation_time > 0 ? avg_creation_time : 180 # 3 min voice

    time_saved_total = voice_count * (manual_estimate_seconds - voice_estimate_seconds)

    {
      voice_invoices: voice_count,
      avg_creation_time_seconds: voice_estimate_seconds,
      manual_estimate_seconds: manual_estimate_seconds,
      time_saved_total_seconds: [time_saved_total, 0].max,
      speed_multiplier: voice_estimate_seconds > 0 ? (manual_estimate_seconds.to_f / voice_estimate_seconds).round(1) : 4.0
    }
  end

  # ── Tracking helper (call from controllers) ──

  def self.track!(user_id:, event_type:, metadata: {}, duration_seconds: nil, amount: nil, currency: nil, status: nil, source: nil)
    create!(
      user_id: user_id,
      event_type: event_type,
      metadata: metadata || {},
      duration_seconds: duration_seconds,
      amount: amount,
      currency: currency,
      status: status,
      source: source
    )
  rescue => e
    Rails.logger.warn("AnalyticsEvent.track! failed: #{e.message}")
    nil
  end
end
