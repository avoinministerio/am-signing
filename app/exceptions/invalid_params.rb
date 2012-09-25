#encoding: UTF-8

class InvalidParams < StandardError
  def initialize(msg)
    super(msg)
    Rails.logger.info self.to_s
  end
end
