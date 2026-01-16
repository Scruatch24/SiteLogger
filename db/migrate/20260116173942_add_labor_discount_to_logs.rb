class AddLaborDiscountToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :labor_discount_flat, :decimal
    add_column :logs, :labor_discount_percent, :decimal
  end
end
