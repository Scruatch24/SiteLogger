class CreateAnalyticsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_events do |t|
      t.bigint :user_id, null: false
      t.string :event_type, null: false
      t.jsonb :metadata, default: {}
      t.decimal :duration_seconds, precision: 10, scale: 2
      t.decimal :amount, precision: 12, scale: 2
      t.string :currency
      t.string :status
      t.string :source

      t.timestamps
    end

    add_index :analytics_events, :user_id
    add_index :analytics_events, :event_type
    add_index :analytics_events, [:user_id, :event_type, :created_at], name: "idx_analytics_user_event_time"
    add_index :analytics_events, [:user_id, :created_at], name: "idx_analytics_user_time"
    add_foreign_key :analytics_events, :users, on_delete: :cascade
  end
end
