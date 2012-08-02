# encoding: UTF-8

FactoryGirl.define do
  factory :signature do
    citizen_id { rand(1000) }
    idea_id { rand(1000) }
    idea_date { 1.years.ago }
    idea_title "My Law"
    idea_mac "randomhash"
    accept_general true
    accept_non_eu_server true
    accept_science true
    accept_publicity "normal"
  end
end
