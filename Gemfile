source 'https://rubygems.org'

gem 'rails', '3.2.7'
gem 'jquery-rails'
gem "haml", ">= 3.1.6"
gem "haml-rails", ">= 0.3.4", :group => :development
gem "rails-i18n"
gem "simple_form"
gem "twitter-bootstrap-rails"
gem "unicorn"
gem "httparty"

group :assets do
  gem "sass-rails"
  gem "coffee-rails"
  gem "uglifier"
  gem "therubyracer", :platform => :ruby
end

group :development do
  gem "guard-rspec"
  gem "guard-spork"
  gem 'sqlite3'
end

group :test, :development do
  gem "factory_girl_rails"
  gem "rspec-rails", "~> 2.0"
  gem "shoulda-matchers"
  gem 'sqlite3'
end

group :production do
  gem "pg"
end