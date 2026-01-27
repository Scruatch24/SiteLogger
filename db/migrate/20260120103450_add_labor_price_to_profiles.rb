class AddLaborPriceToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :labor_price, :decimal
  end
end
