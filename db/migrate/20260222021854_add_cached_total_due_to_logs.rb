class AddCachedTotalDueToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :cached_total_due, :decimal, precision: 12, scale: 2, default: 0.0
    add_index :logs, [:user_id, :status, :created_at], name: "idx_logs_user_status_created"
  end
end
