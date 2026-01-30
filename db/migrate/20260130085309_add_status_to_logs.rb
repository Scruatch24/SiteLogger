class AddStatusToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :status, :string, default: 'draft', null: false
    add_index :logs, :status
  end
end
