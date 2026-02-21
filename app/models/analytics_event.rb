class AnalyticsEvent < ApplicationRecord
  belongs_to :user

  # Event types
  VOICE_RECORDING = "voice_recording"
  INVOICE_CREATED = "invoice_created"
  TRANSCRIPTION_SUCCESS = "transcription_success"
  TRANSCRIPTION_FAILURE = "transcription_failure"
  VOICE_PROCESSING = "voice_processing"

  EVENT_TYPES = [
    VOICE_RECORDING,
    INVOICE_CREATED,
    TRANSCRIPTION_SUCCESS,
    TRANSCRIPTION_FAILURE,
    VOICE_PROCESSING
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
    this_month = logs.where("created_at >= ?", Time.current.beginning_of_month).count
    last_month = logs.where(created_at: Time.current.last_month.beginning_of_month..Time.current.beginning_of_month).count

    voice_recordings = events.of_type(VOICE_RECORDING).count
    transcription_successes = events.of_type(TRANSCRIPTION_SUCCESS).count
    transcription_failures = events.of_type(TRANSCRIPTION_FAILURE).count
    total_transcriptions = transcription_successes + transcription_failures
    success_rate = total_transcriptions > 0 ? ((transcription_successes.to_f / total_transcriptions) * 100).round(1) : 100.0

    active_clients = logs.where.not(client: [nil, ""]).distinct.count(:client)

    {
      total_invoices: total_invoices,
      this_month_invoices: this_month,
      last_month_invoices: last_month,
      voice_recordings: voice_recordings,
      success_rate: success_rate,
      active_clients: active_clients,
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

    {
      total_amount: total_amount,
      invoice_count: count,
      avg_amount: avg_amount
    }
  end

  def self.top_clients_for(user_id, limit: 5)
    logs = Log.where(user_id: user_id).kept.where.not(client: [nil, ""])

    client_stats = logs
      .group(:client)
      .select("client, COUNT(*) as invoice_count, MAX(created_at) as last_invoice_at")
      .order("invoice_count DESC")
      .limit(limit)

    client_stats.map do |row|
      {
        name: row.client,
        invoice_count: row.invoice_count,
        last_invoice_at: row.last_invoice_at
      }
    end
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
