class AddUserIdToLogsAndProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :user_id, :integer
    add_index :logs, :user_id
    add_column :profiles, :user_id, :integer
    add_index :profiles, :user_id
  end
end
