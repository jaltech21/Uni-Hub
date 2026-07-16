require "digest"
require "securerandom"

class RefreshToken < ApplicationRecord
  REFRESH_TOKEN_LIFETIME = 30.days

  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.issue!(user, user_agent: nil, ip_address: nil)
    raw_token = SecureRandom.urlsafe_base64(64)
    record = create!(
      user: user,
      token_digest: digest(raw_token),
      expires_at: REFRESH_TOKEN_LIFETIME.from_now,
      user_agent: user_agent,
      ip_address: ip_address
    )
    [record, raw_token]
  end

  def self.find_active(raw_token)
    return nil if raw_token.blank?
    active.find_by(token_digest: digest(raw_token))
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !revoked? && expires_at.future?
  end
end
