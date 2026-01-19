class AddGlobalDiscountToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :global_discount_flat, :decimal, precision: 10, scale: 2
    add_column :logs, :global_discount_percent, :decimal, precision: 5, scale: 2
  end
end
