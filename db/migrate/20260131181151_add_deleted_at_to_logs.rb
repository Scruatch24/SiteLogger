class AddDeletedAtToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :deleted_at, :datetime
    add_index :logs, :deleted_at
  end
end
