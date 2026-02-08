class UsageEvent < ApplicationRecord
  belongs_to :user, optional: true
end
