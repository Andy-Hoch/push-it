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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_071958) do
  create_table "games", force: :cascade do |t|
    t.string "code", null: false
    t.string "status", default: "lobby", null: false
    t.integer "host_id", null: false
    t.integer "winner_id"
    t.json "state", default: {}, null: false
    t.integer "turn_seq", default: 0, null: false
    t.integer "turn_seconds", default: 45, null: false
    t.integer "target_score", default: 200, null: false
    t.string "rematch_code"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_games_on_code", unique: true
    t.index ["host_id"], name: "index_games_on_host_id"
    t.index ["winner_id"], name: "index_games_on_winner_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name", null: false
    t.string "guest_token", null: false
    t.integer "user_id"
    t.integer "games_played", default: 0, null: false
    t.integer "games_won", default: 0, null: false
    t.integer "jackpot_count", default: 0, null: false
    t.integer "best_round", default: 0, null: false
    t.integer "total_points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_token"], name: "index_profiles_on_guest_token", unique: true
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "seats", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "profile_id", null: false
    t.integer "position", null: false
    t.integer "total_score", default: 0, null: false
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "profile_id"], name: "index_seats_on_game_id_and_profile_id", unique: true
    t.index ["game_id"], name: "index_seats_on_game_id"
    t.index ["profile_id"], name: "index_seats_on_profile_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "games", "profiles", column: "host_id"
  add_foreign_key "games", "profiles", column: "winner_id"
  add_foreign_key "profiles", "users"
  add_foreign_key "seats", "games"
  add_foreign_key "seats", "profiles"
  add_foreign_key "sessions", "users"
end
