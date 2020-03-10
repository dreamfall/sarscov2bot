# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_03_10_175320) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "country_statistical_entries", force: :cascade do |t|
    t.string "country", null: false
    t.integer "total_cases_number", default: 0, null: false
    t.integer "deaths_number", default: 0, null: false
    t.integer "recovered_number", default: 0, null: false
    t.datetime "created_at", null: false
  end

  create_table "statistical_entries", force: :cascade do |t|
    t.integer "total_cases_number", null: false
    t.integer "deaths_number", null: false
    t.integer "recovered_number", null: false
    t.datetime "created_at", null: false
  end

end
