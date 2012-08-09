#encoding: UTF-8

class InvalidMac < StandardError
  def to_s
    "Invalid MAC"
  end
end
