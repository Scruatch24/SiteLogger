class CreateUsageEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :usage_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :event_type
      t.string :session_id

      t.timestamps
    end
  end
end
