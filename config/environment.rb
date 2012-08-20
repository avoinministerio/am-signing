# Load the rails application
require File.expand_path('../application', __FILE__)

# preload various tokens to local ENV
api_tokens = YAML.load(File.read(Rails.root.join('config', 'api_keys', "#{Rails.env}.yml"))) rescue {}
api_tokens.each{ |key, val| ENV[key] = val }

# Initialize the rails application
Signing::Application.initialize!