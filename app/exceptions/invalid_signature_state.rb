#encoding: UTF-8

class InvalidSignatureState < StandardError
  def initialize(expected_state, signature)
    @expected_state = expected_state
    @signature = signature
  end

  def to_s
    "Signature with ID #{@signature_id} was expected to have state '#{expected_state}' but the state was '#{@signature.state}'"
  end
end
