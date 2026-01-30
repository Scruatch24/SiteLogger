class AddTaxRateToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :tax_rate, :decimal
  end
end
