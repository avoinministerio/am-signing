#encoding: UTF-8

module ShortcutTokenValidator
  AUTHENTICATION_VALIDITY_TIME = 2

  def self.valid?(birth_date, authenticated_at, authentication_token)
    begin
      DateTime.parse(birth_date)
      authentication_token =~ /^\h*$/ && (authenticated_at.to_time > AUTHENTICATION_VALIDITY_TIME.minutes.ago) &&
        valid_authentication_token?(birth_date, authenticated_at, authentication_token)
    rescue Exception => e
      false
    end
  end

  def self.valid_authentication_token?(birth_date, authenticated_at, authentication_token)
    authentication_token == calculate_authentication_token(birth_date, authenticated_at)
  end

  def self.calculate_authentication_token(birth_date, authenticated_at)
    Signing::HmacSha256.sign(ENV['authentication_token_secret'], birth_date + authenticated_at)
  end
end
