class Log < ApplicationRecord
  serialize :tasks, coder: JSON
  serialize :credits, coder: JSON
  belongs_to :user, optional: true
  belongs_to :client_record, class_name: "Client", foreign_key: "client_id", optional: true, counter_cache: :invoices_count

  has_many :log_category_assignments, dependent: :destroy
  has_many :categories, through: :log_category_assignments

  STATUSES = %w[draft sent paid overdue].freeze

  scope :kept, -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  def discard
    update(deleted_at: Time.current)
  end

  def discarded?
    deleted_at.present?
  end

  def overdue?
    return false if status == "paid"
    return true if status == "overdue" # Manually set

    # Auto-check: if sent/draft and past due_date
    if due_date.present? && (status == "draft" || status == "sent")
      begin
        # Attempt to parse due_date. We need to be careful with formatting if it's not ISO.
        # Home page uses log.date || log.created_at.strftime("%b %d, %Y")
        # Let's assume due_date is stored in a way we can parse.
        parsed_due = Date.parse(due_date) rescue nil
        return parsed_due < Date.today if parsed_due
      rescue
        false
      end
    end
    false
  end

  def current_status
    overdue? ? "overdue" : status
  end

  before_create :assign_invoice_number

  def display_number
    # Guest users always see INV-1001 (they can't save anyway)
    return 1001 if user.nil?

    # Use the persisted invoice_number if available (check if method exists to be safe against stale schema cache)
    if respond_to?(:invoice_number) && invoice_number.present?
      return invoice_number
    end

    # Fallback for unsaved records (preview):
    self.class.next_display_number(user, ip_address, session_id)
  end

  def self.next_display_number(user = nil, ip_address = nil, session_id = nil)
    # Find the maximum existing invoice number for this user (or guest)
    scope = if user
      where(user_id: user.id)
    elsif ip_address.present? && session_id.present?
      # For guests, use both IP and session_id with OR to find their invoices
      where(user_id: nil).where("ip_address = ? OR session_id = ?", ip_address, session_id)
    elsif ip_address.present?
      where(user_id: nil, ip_address: ip_address)
    elsif session_id.present?
      where(user_id: nil, session_id: session_id)
    else
      where(user_id: nil)
    end

    # Retry logic for stale schema cache
    begin
      # We include deleted ones in the max ID check to avoid reusable IDs
      max_num = scope.maximum(:invoice_number)
    rescue StandardError => e
      Rails.logger.warn("Log.next_display_number: schema cache miss, retrying — #{e.message}")
      reset_column_information
      max_num = scope.maximum(:invoice_number)
    end

    # If no invoices exist, start at 1001
    # If invoices exist, increment the highest number
    (max_num || 1000) + 1
  end

  private

  def assign_invoice_number
    # Assign the next number only if not already set
    self.invoice_number ||= self.class.next_display_number(user, ip_address, session_id)
  end

  # Retry on unique constraint violation (race condition: two concurrent saves)
  after_validation :retry_invoice_number_on_conflict

  def retry_invoice_number_on_conflict
    return unless new_record? && invoice_number.present?

    retries = 0
    begin
      # Test uniqueness before save by checking if the number already exists
      scope = user ? self.class.where(user_id: user.id) : self.class.where(user_id: nil)
      while scope.exists?(invoice_number: invoice_number) && retries < 5
        self.invoice_number = self.class.next_display_number(user, ip_address, session_id)
        retries += 1
      end
    rescue StandardError => e
      Rails.logger.warn("Log#retry_invoice_number_on_conflict: #{e.message}")
    end
  end
end
