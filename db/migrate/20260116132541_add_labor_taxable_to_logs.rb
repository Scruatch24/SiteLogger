class AddLaborTaxableToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :labor_taxable, :boolean
  end
end
