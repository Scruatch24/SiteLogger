class RenameMaterialsToProductsInLogs < ActiveRecord::Migration[8.0]
  def change
    rename_column :logs, :materials, :products rescue nil

    change_column_default :profiles, :tax_scope, from: "labor,materials_only", to: "labor,products_only"
    change_column_default :logs, :tax_scope, from: "labor,materials_only", to: "labor,products_only"

    # Update existing values in the database for consistency
    # (Note: This is safe even if some rows are already updated)
    reversible do |dir|
      dir.up do
        execute("UPDATE profiles SET tax_scope = 'labor,products_only' WHERE tax_scope = 'labor,materials_only'")
        execute("UPDATE logs SET tax_scope = 'labor,products_only' WHERE tax_scope = 'labor,materials_only'")
      end
    end
  end
end
