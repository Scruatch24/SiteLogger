class Client < ApplicationRecord
  belongs_to :user
  has_many :logs, foreign_key: "client_id", dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :ordered, -> { order(invoices_count: :desc, name: :asc) }
  scope :search, ->(term) {
    where("name ILIKE :q OR email ILIKE :q OR phone ILIKE :q", q: "%#{term}%") if term.present?
  }

  def display_initials
    name.split(/\s+/).map { |w| w[0] }.join("").upcase.first(2)
  end

  def last_invoice_date
    logs.kept.maximum(:created_at)
  end
end
