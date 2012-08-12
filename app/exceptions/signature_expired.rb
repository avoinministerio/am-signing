#encoding: UTF-8
class SignatureExpired < StandardError
  def initialize(signature_id, created_at)
    @created_at = created_at
    @signature_id = signature_id
  end

  def to_s
    "Signature with ID #{@signature_id} has been created at #{@created_at} and is now expired"
  end
end