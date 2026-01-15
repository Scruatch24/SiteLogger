class Profile < ApplicationRecord
    # This line allows you to attach a logo image to the profile
    has_one_attached :logo
  end