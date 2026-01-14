class AddPaymentInfoToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :payment_instructions, :text
    add_column :profiles, :tax_rate, :decimal
  end
end
