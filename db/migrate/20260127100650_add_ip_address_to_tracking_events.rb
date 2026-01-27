class AddIpAddressToTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :tracking_events, :ip_address, :string
  end
end
