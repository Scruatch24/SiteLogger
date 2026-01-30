class ChangeDefaultTaxScopeOnProfiles < ActiveRecord::Migration[8.0]
  def change
    change_column_default :profiles, :tax_scope, from: "total", to: "labor,materials_only"
    change_column_default :logs, :tax_scope, from: "total", to: "labor,materials_only"
  end
end
