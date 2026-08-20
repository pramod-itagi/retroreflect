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

ActiveRecord::Schema[7.1].define(version: 2026_08_20_133000) do
  create_table "action_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "retrospective_id"
    t.bigint "created_by_id", null: false
    t.bigint "owner_id", null: false
    t.string "title", null: false
    t.text "description"
    t.date "due_on", null: false
    t.string "status", limit: 32, default: "open", null: false
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cancelled_by_id"], name: "index_action_items_on_cancelled_by_id"
    t.index ["completed_by_id"], name: "index_action_items_on_completed_by_id"
    t.index ["created_by_id"], name: "index_action_items_on_created_by_id"
    t.index ["due_on"], name: "index_action_items_on_due_on"
    t.index ["owner_id"], name: "index_action_items_on_owner_id"
    t.index ["retrospective_id"], name: "index_action_items_on_retrospective_id"
    t.index ["team_id", "status"], name: "index_action_items_on_team_id_and_status"
    t.index ["team_id"], name: "index_action_items_on_team_id"
  end

  create_table "feedback_drafts", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "retrospective_id", null: false
    t.bigint "participation_id", null: false
    t.string "category", limit: 32, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participation_id"], name: "index_feedback_drafts_on_participation_id"
    t.index ["retrospective_id"], name: "index_feedback_drafts_on_retrospective_id"
  end

  create_table "feedback_items", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "retrospective_id", null: false
    t.string "category", limit: 32, null: false
    t.text "body", null: false
    t.integer "reveal_position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["retrospective_id", "category"], name: "index_feedback_items_on_retrospective_id_and_category"
    t.index ["retrospective_id", "reveal_position"], name: "index_feedback_items_on_retrospective_id_and_reveal_position", unique: true
    t.index ["retrospective_id"], name: "index_feedback_items_on_retrospective_id"
  end

  create_table "memberships", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "user_id", null: false
    t.string "role", limit: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "role"], name: "index_memberships_on_team_id_and_role"
    t.index ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "participations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "retrospective_id", null: false
    t.bigint "user_id", null: false
    t.string "invitation_token_digest", limit: 64
    t.datetime "invited_at"
    t.datetime "accessed_at"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invitation_token_digest"], name: "index_participations_on_invitation_token_digest", unique: true
    t.index ["retrospective_id", "submitted_at"], name: "index_participations_on_retrospective_id_and_submitted_at"
    t.index ["retrospective_id", "user_id"], name: "index_participations_on_retrospective_id_and_user_id", unique: true
    t.index ["retrospective_id"], name: "index_participations_on_retrospective_id"
    t.index ["user_id"], name: "index_participations_on_user_id"
  end

  create_table "retrospectives", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "created_by_id", null: false
    t.string "title", null: false
    t.string "sprint_label", limit: 100
    t.datetime "scheduled_at"
    t.string "status", limit: 20, default: "draft", null: false
    t.datetime "collecting_started_at"
    t.datetime "revealed_at"
    t.datetime "closed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "running_team_id", type: :bigint, as: "(case when (`status` in (_utf8mb4'draft',_utf8mb4'collecting',_utf8mb4'discussing')) then `team_id` else NULL end)", stored: true
    t.index ["created_by_id"], name: "index_retrospectives_on_created_by_id"
    t.index ["running_team_id"], name: "index_retrospectives_one_running_per_team", unique: true
    t.index ["team_id", "status"], name: "index_retrospectives_on_team_id_and_status"
    t.index ["team_id"], name: "index_retrospectives_on_team_id"
  end

  create_table "teams", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_teams_on_created_by_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", limit: 100, null: false
    t.datetime "confirmed_at"
    t.string "confirmation_token_digest", limit: 64
    t.datetime "confirmation_sent_at"
    t.string "password_reset_token_digest", limit: 64
    t.datetime "password_reset_sent_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token_digest"], name: "index_users_on_confirmation_token_digest", unique: true
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["password_reset_token_digest"], name: "index_users_on_password_reset_token_digest", unique: true
  end

  add_foreign_key "action_items", "retrospectives", on_delete: :nullify
  add_foreign_key "action_items", "teams"
  add_foreign_key "action_items", "users", column: "cancelled_by_id"
  add_foreign_key "action_items", "users", column: "completed_by_id"
  add_foreign_key "action_items", "users", column: "created_by_id"
  add_foreign_key "action_items", "users", column: "owner_id"
  add_foreign_key "feedback_drafts", "participations", on_delete: :cascade
  add_foreign_key "feedback_drafts", "retrospectives", on_delete: :cascade
  add_foreign_key "feedback_items", "retrospectives", on_delete: :cascade
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "participations", "retrospectives", on_delete: :cascade
  add_foreign_key "participations", "users"
  add_foreign_key "retrospectives", "teams"
  add_foreign_key "retrospectives", "users", column: "created_by_id"
  add_foreign_key "teams", "users", column: "created_by_id"
end
