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

ActiveRecord::Schema[8.0].define(version: 2026_01_14_190632) do
  create_schema "auth"
  create_schema "neon_auth"
  create_schema "pgrst"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_session_jwt"

  create_table "logs", force: :cascade do |t|
    t.string "date"
    t.string "client"
    t.string "time"
    t.text "tasks"
    t.text "materials"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end
end
