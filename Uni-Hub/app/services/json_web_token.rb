require "jwt"

class JsonWebToken
  ACCESS_TOKEN_LIFETIME = 1.hour
  ALGORITHM = "HS256".freeze

  class DecodeError < StandardError; end
  class ExpiredError < DecodeError; end

  def self.encode(payload, expires_at: ACCESS_TOKEN_LIFETIME.from_now)
    JWT.encode(payload.merge(exp: expires_at.to_i), secret, ALGORITHM)
  end

  def self.decode(token)
    decoded, _header = JWT.decode(token, secret, true, algorithm: ALGORITHM)
    decoded.with_indifferent_access
  rescue JWT::ExpiredSignature => e
    raise ExpiredError, e.message
  rescue JWT::DecodeError => e
    raise DecodeError, e.message
  end

  def self.secret
    Rails.application.credentials.secret_key_base || ENV.fetch("SECRET_KEY_BASE")
  end
end
