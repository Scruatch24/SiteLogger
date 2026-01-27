class Profile < ApplicationRecord
    # Active Storage association for the logo
    has_one_attached :logo do |attachable|
      # attachable.variant :thumb, resize_to_limit: [100, 100]
      # attachable.variant :display, resize_to_limit: [300, 300]
    end

    validates :business_name, presence: true
    validates :email, presence: true

    # These validators now work thanks to the active_storage_validations gem
    validates :logo, content_type: [ "image/png", "image/jpg", "image/jpeg" ],
                    size: { less_than: 2.megabytes, message: "is too large (max 2MB)" }

    attr_accessor :remove_logo

    before_save :check_remove_logo
    before_save :set_free_plan_if_guest
    validate :validate_address_lines
    validate :validate_payment_instructions_lines

    PLAN_LIMITS = {
      "guest" => 200,
      "free" => 2000,
      "paid" => 10000
    }.freeze

    AUDIO_LIMITS = {
      "guest" => 30,
      "free" => 120,
      "paid" => 600
    }.freeze

    def char_limit
      PLAN_LIMITS[plan.presence || "guest"] || 200
    end

    def audio_limit
      AUDIO_LIMITS[plan.presence || "guest"] || 30
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
      if address.to_s.lines.count > 4
        errors.add(:address, "cannot exceed 4 lines")
      end
    end

    def validate_payment_instructions_lines
      return if payment_instructions.blank?
      if payment_instructions.to_s.lines.count > 8
        errors.add(:payment_instructions, "cannot exceed 8 lines")
      end
    end

    def set_free_plan_if_guest
      self.plan = "free" if plan.blank? || plan == "guest"
    end
end
