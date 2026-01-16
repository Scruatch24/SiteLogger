class AddTaxScopeToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :tax_scope, :string, null: false, default: "total"
  end
end
