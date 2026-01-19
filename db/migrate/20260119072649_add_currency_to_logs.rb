class AddCurrencyToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :currency, :string
  end
end
