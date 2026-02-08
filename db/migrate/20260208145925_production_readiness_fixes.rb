class ProductionReadinessFixes < ActiveRecord::Migration[8.0]
  def change
    # 1. Make invoice_number unique per user (fixes race condition)
    #    Remove old non-unique index, add unique one
    remove_index :logs, [:user_id, :invoice_number], name: "index_logs_on_user_id_and_invoice_number", if_exists: true
    add_index :logs, [:user_id, :invoice_number], unique: true, name: "index_logs_on_user_id_and_invoice_number"

    # 2. Add foreign keys (logs allows NULL user_id for guests)
    add_foreign_key :logs, :users, column: :user_id, on_delete: :nullify, validate: false
    add_foreign_key :profiles, :users, column: :user_id, on_delete: :cascade, validate: false

    # 3. Add indexes on tracking_events for common query patterns
    add_index :tracking_events, [:event_name, :ip_address, :created_at], name: "idx_tracking_events_on_event_ip_created"
    add_index :tracking_events, [:event_name, :user_id, :created_at], name: "idx_tracking_events_on_event_user_created"
  end
end
