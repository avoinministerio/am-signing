#encoding: UTF-8

module Signing
  module HmacSha256
    def sign key, message
      message = message.to_param unless message.is_a? String
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, key, message).upcase
    end

    module_function :sign
  end
end
