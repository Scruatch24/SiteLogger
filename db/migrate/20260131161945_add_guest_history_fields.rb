class AddGuestHistoryFields < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :ip_address, :string unless column_exists?(:logs, :ip_address)
    add_column :logs, :session_id, :string unless column_exists?(:logs, :session_id)
    add_column :tracking_events, :target_id, :string unless column_exists?(:tracking_events, :target_id)
  end
end
