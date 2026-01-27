class CreateTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :tracking_events do |t|
      t.string :event_name
      t.integer :user_id
      t.string :session_id

      t.timestamps
    end
  end
end
