class AddBillingModeToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :billing_mode, :string
  end
end
