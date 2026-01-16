class AddTaxScopeToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :tax_scope, :string, null: false, default: "total"
  end
end
