# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_21_235822) do
  create_schema "auth"
  create_schema "neon_auth"
  create_schema "pgrst"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_session_jwt"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analytics_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.decimal "duration_seconds", precision: 10, scale: 2
    t.decimal "amount", precision: 12, scale: 2
    t.string "currency"
    t.string "status"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_analytics_events_on_event_type"
    t.index ["user_id", "created_at"], name: "idx_analytics_user_time"
    t.index ["user_id", "event_type", "created_at"], name: "idx_analytics_user_event_time"
    t.index ["user_id"], name: "index_analytics_events_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.string "icon"
    t.string "icon_type"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "tax_id"
    t.text "notes"
    t.integer "invoices_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "log_category_assignments", force: :cascade do |t|
    t.bigint "log_id", null: false
    t.bigint "category_id", null: false
    t.datetime "pinned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_log_category_assignments_on_category_id"
    t.index ["log_id"], name: "index_log_category_assignments_on_log_id"
  end

  create_table "logs", force: :cascade do |t|
    t.string "date"
    t.string "client"
    t.string "time"
    t.text "tasks"
    t.text "materials"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "billing_mode"
    t.string "tax_scope", default: "labor,materials_only", null: false
    t.boolean "labor_taxable"
    t.decimal "labor_discount_flat"
    t.decimal "labor_discount_percent"
    t.string "due_date"
    t.decimal "global_discount_flat"
    t.decimal "global_discount_percent"
    t.decimal "credit_flat", precision: 10, scale: 2
    t.string "credit_reason"
    t.string "currency"
    t.decimal "hourly_rate"
    t.string "discount_tax_rule"
    t.text "credits"
    t.string "global_discount_message"
    t.integer "user_id"
    t.string "accent_color", default: "#EA580C"
    t.boolean "pinned"
    t.text "raw_summary"
    t.decimal "tax_rate"
    t.integer "invoice_number"
    t.string "status", default: "draft", null: false
    t.datetime "pinned_at"
    t.datetime "favorites_pinned_at"
    t.string "ip_address"
    t.string "session_id"
    t.datetime "deleted_at"
    t.bigint "client_id"
    t.datetime "paid_at"
    t.index ["client_id"], name: "index_logs_on_client_id"
    t.index ["deleted_at"], name: "index_logs_on_deleted_at"
    t.index ["status"], name: "index_logs_on_status"
    t.index ["user_id", "invoice_number"], name: "index_logs_on_user_id_and_invoice_number", unique: true
    t.index ["user_id", "status", "deleted_at"], name: "idx_logs_user_status_kept"
    t.index ["user_id"], name: "index_logs_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "business_name"
    t.string "phone"
    t.string "email"
    t.string "address"
    t.string "tax_id"
    t.decimal "hourly_rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "payment_instructions"
    t.decimal "tax_rate"
    t.string "billing_mode"
    t.string "currency"
    t.string "tax_scope", default: "labor,materials_only", null: false
    t.string "invoice_style"
    t.string "discount_tax_rule", default: "post_tax"
    t.decimal "labor_price"
    t.string "plan", default: "guest"
    t.integer "user_id"
    t.string "accent_color", default: "#EA580C"
    t.boolean "dark_mode", default: false, null: false
    t.integer "hours_per_workday", default: 8
    t.string "system_language"
    t.string "document_language"
    t.string "transcription_language"
    t.text "note"
    t.boolean "onboarded", default: false, null: false
    t.string "bog_payment_id"
    t.string "bog_payment_status"
    t.string "bog_order_id"
    t.string "bog_currency"
    t.decimal "bog_amount", precision: 10, scale: 2
    t.string "paddle_subscription_id"
    t.string "paddle_price_id"
    t.string "paddle_customer_email"
    t.string "paddle_subscription_status"
    t.datetime "paddle_next_bill_at"
    t.string "paddle_customer_id"
    t.datetime "paddle_cancelled_at"
    t.decimal "analytics_alert_threshold", precision: 12, scale: 2, default: "5000.0"
    t.index ["paddle_customer_email"], name: "index_profiles_on_paddle_customer_email"
    t.index ["paddle_subscription_id"], name: "index_profiles_on_paddle_subscription_id"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.string "event_name"
    t.integer "user_id"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ip_address"
    t.string "target_id"
    t.index ["event_name", "ip_address", "created_at"], name: "idx_tracking_events_on_event_ip_created"
    t.index ["event_name", "user_id", "created_at"], name: "idx_tracking_events_on_event_user_created"
  end

  create_table "usage_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "ip_address"
    t.string "event_type"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "data_hash"
    t.index ["data_hash"], name: "index_usage_events_on_data_hash"
    t.index ["user_id"], name: "index_usage_events_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "session_token"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "analytics_events", "users", on_delete: :cascade
  add_foreign_key "categories", "users"
  add_foreign_key "clients", "users"
  add_foreign_key "log_category_assignments", "categories"
  add_foreign_key "log_category_assignments", "logs"
  add_foreign_key "logs", "clients"
  add_foreign_key "logs", "users", on_delete: :nullify, validate: false
  add_foreign_key "profiles", "users", on_delete: :cascade, validate: false
  add_foreign_key "usage_events", "users"
end
