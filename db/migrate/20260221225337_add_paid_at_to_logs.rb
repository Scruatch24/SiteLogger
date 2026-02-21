class AddPaidAtToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :paid_at, :datetime
    add_index :logs, [:user_id, :status, :deleted_at], name: "idx_logs_user_status_kept"

    # Backfill paid_at for existing paid invoices
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE logs SET paid_at = updated_at WHERE status = 'paid' AND paid_at IS NULL AND deleted_at IS NULL
        SQL
      end
    end
  end
end
