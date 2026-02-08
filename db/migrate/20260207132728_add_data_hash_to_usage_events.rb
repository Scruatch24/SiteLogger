class AddDataHashToUsageEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :usage_events, :data_hash, :string
    add_index :usage_events, :data_hash
  end
end
