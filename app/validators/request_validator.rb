#encoding: UTF-8

module RequestValidator
  class KeyNotFoundError < RuntimeError; end

  @@message = [:idea_id, :idea_title, :idea_date, :idea_mac,
               :citizen_id, :accept_general, :accept_non_eu_server,
               :accept_publicity, :accept_science,
               :service, :first_names, :last_name]
  @@options = [:success_url, :failure_url]
  @@root =    [:last_fill_birth_date, :last_fill_occupancy_county,
               :authentication_token, :authenticated_at]

  def self.validate!(params, signature)
    begin
      valid_params = {}
      valid_params[:message] = check_params(@@message, params[:message])
      valid_params[:options] = check_params(@@options, params[:options])
      valid_params.merge!(check_params(@@root, params))

      raise ::InvalidParams, "Invalid MAC for params #{params}" unless Signing::HmacSha256.sign(requestor_secret, valid_params.to_param) == signature
    rescue KeyNotFoundError => e
      raise ::InvalidParams, "Parameter not found: #{e}"
    end
  end

  def self.check_params(required_keys_in_order, hash_from_request)
    required_keys_in_order.reduce({}) do |ordered_hash, key|
      raise KeyNotFoundError, key unless hash_from_request.has_key?(key)

      ordered_hash[key] = hash_from_request[key]
      ordered_hash
    end
  end

  def self.requestor_secret
    ENV['requestor_secret']
  end
end
