class Category < ApplicationRecord
  belongs_to :user

  has_many :log_category_assignments, dependent: :destroy
  has_many :logs, -> { kept.joins(:log_category_assignments).order("log_category_assignments.pinned_at ASC NULLS LAST, logs.created_at DESC") }, through: :log_category_assignments

  has_one_attached :custom_icon

  validates :name, presence: true
end
