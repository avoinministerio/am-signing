# Load the rails application
require File.expand_path('../application', __FILE__)

# preload various tokens to local ENV
begin
  api_tokens = YAML.load(File.read(Rails.root.join('config', 'api_keys', "#{Rails.env}.yml"))) rescue {}
  api_tokens.each{ |key, val| ENV[key] = val }
rescue
  puts "No secret keys found" # We don't have logger yet, just puts it to console
end

# Initialize the rails application
Signing::Application.initialize!

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
