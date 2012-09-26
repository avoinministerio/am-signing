# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120909123308) do

  create_table "signatures", :force => true do |t|
    t.integer  "citizen_id"
    t.integer  "idea_id"
    t.string   "idea_title"
    t.date     "idea_date"
    t.string   "idea_mac"
    t.string   "first_names"
    t.string   "last_name"
    t.date     "birth_date"
    t.string   "occupancy_county"
    t.boolean  "vow"
    t.date     "signing_date"
    t.string   "state"
    t.string   "stamp"
    t.boolean  "accept_general"
    t.boolean  "accept_non_eu_server"
    t.boolean  "accept_science"
    t.string   "accept_publicity"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.string   "service"
    t.string   "success_auth_url"
  end

end
