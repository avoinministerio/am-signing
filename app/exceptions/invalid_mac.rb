#encoding: UTF-8

class InvalidMac < StandardError
	def initialize(params, param_string, mac_param_string, requestor_secret)
		@params, @param_string, @mac_param_string, @requestor_secret = params, param_string, mac_param_string, requestor_secret
	end
  def to_s
    "Invalid MAC #{@params} || #{@param_string} || #{@mac_param_string} || #{@requestor_secret}"
  end
end
