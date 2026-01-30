class AddPinnedToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :pinned, :boolean
  end
end
