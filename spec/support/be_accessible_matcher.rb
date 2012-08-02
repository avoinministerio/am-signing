# Review: http://stackoverflow.com/questions/9306392/how-to-test-attr-accessible-fields-in-rspec - jaakko

RSpec::Matchers.define :be_accessible do |attribute|
  match do |response|
    response.class.accessible_attributes.include?(attribute)
  end
  description { "be accessible to mass-assignment: #{attribute}" }
  failure_message_for_should { ":#{attribute} should be accessible to mass-assignment" }
  failure_message_for_should_not { ":#{attribute} should not be accessible to mass-assignment" }
end
