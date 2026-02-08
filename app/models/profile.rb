class Profile < ApplicationRecord
    # Active Storage association for the logo
    has_one_attached :logo do |attachable|
      # attachable.variant :thumb, resize_to_limit: [100, 100]
      # attachable.variant :display, resize_to_limit: [300, 300]
    end
    belongs_to :user, optional: true

    validates :business_name, presence: true
    validates :email, presence: true
    validates :tax_rate, numericality: { less_than_or_equal_to: 100, allow_nil: true }
    validates :hourly_rate, numericality: { less_than_or_equal_to: 999999999, allow_nil: true }
    validates :hours_per_workday, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 24, allow_nil: true }

    # These validators now work thanks to the active_storage_validations gem
    validates :logo, content_type: [ "image/png", "image/jpg", "image/jpeg" ],
                    size: { less_than: 2.megabytes, message: "is too large (max 2MB)" }

    attr_accessor :remove_logo

    before_save :check_remove_logo
    validate :validate_address_lines
    validate :validate_payment_instructions_lines

    PLAN_LIMITS = {
      "guest" => 150,
      "free" => 400,
      "paid" => 10000
    }.freeze

    AUDIO_LIMITS = {
      "guest" => 30,
      "free" => 60,
      "paid" => 300
    }.freeze

    EXPORT_LIMITS = {
      "guest" => 2,   # per day, per IP
      "free" => 5,    # per day, per account
      "paid" => nil   # unlimited
    }.freeze

    PREVIEW_LIMITS = {
      "guest" => 20,
      "free" => 20,
      "paid" => nil
    }.freeze

    def char_limit
      PLAN_LIMITS[plan.presence || "guest"] || 150
    end

    def audio_limit
      AUDIO_LIMITS[plan.presence || "guest"] || 30
    end

    def export_limit
      EXPORT_LIMITS[plan.presence || "guest"]
    end

    def preview_limit
      PREVIEW_LIMITS[plan.presence || "guest"]
    end

    def guest?
      plan.blank? || plan == "guest"
    end

    def free?
      plan == "free"
    end

    def paid?
      plan == "paid"
    end

    private

    def check_remove_logo
      logo.purge if remove_logo == "1"
    end

    def validate_address_lines
      return if address.blank?
      lines = address.to_s.lines.map(&:chomp)
      if lines.count > 4
        errors.add(:address, "cannot exceed 4 lines")
      end
      if lines.any? { |l| l.length > 50 }
        errors.add(:address, "each line cannot exceed 50 characters")
      end
    end

    def validate_payment_instructions_lines
      return if payment_instructions.blank?
      lines = payment_instructions.to_s.lines.map(&:chomp)
      if lines.count > 8
        errors.add(:payment_instructions, "cannot exceed 8 lines")
      end
      if lines.any? { |l| l.length > 50 }
        errors.add(:payment_instructions, "each line cannot exceed 50 characters")
      end
    end
end
