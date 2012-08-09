#encoding: UTF-8

module Signing
  module HmacSha256
    def sign key, message
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, key, message)
    end

    def sign_array key, array
      sign key, array.join("&")
    end

    module_function :sign, :sign_array
  end
end
