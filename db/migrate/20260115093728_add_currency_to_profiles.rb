class AddCurrencyToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :currency, :string
  end
end
