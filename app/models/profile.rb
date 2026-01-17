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
end
