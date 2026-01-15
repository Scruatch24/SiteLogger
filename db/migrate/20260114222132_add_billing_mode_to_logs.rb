class AddBillingModeToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :billing_mode, :string
  end
end
