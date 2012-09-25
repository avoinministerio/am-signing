#encoding: UTF-8

class InvalidMac < StandardError
	def initialize(params)
		@params = params
    Rails.logger.info self.to_s
	end

  def to_s
    "Invalid MAC for params #{@params}"
  end
end
