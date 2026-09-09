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

ActiveRecord::Schema[8.1].define(version: 2026_09_09_232143) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "student_id", null: false
    t.bigint "trial_class_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "trial_class_id"], name: "index_bookings_on_student_id_and_trial_class_id", unique: true, where: "(status = 1)"
    t.index ["student_id"], name: "index_bookings_on_student_id"
    t.index ["trial_class_id"], name: "index_bookings_on_trial_class_id"
  end

  create_table "parents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "payment_attempts", force: :cascade do |t|
    t.integer "amount_cents"
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.string "simulated_outcome"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_payment_attempts_on_booking_id"
  end

  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_students_on_parent_id"
  end

  create_table "trial_classes", force: :cascade do |t|
    t.integer "capacity", default: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "starts_at"
    t.string "subject"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "bookings", "students"
  add_foreign_key "bookings", "trial_classes"
  add_foreign_key "payment_attempts", "bookings"
  add_foreign_key "students", "parents"
end
