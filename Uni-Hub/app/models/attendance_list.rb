# app/models/attendance_list.rb
class AttendanceList < ApplicationRecord
  VALID_PERIOD = 120 # 2 minutes in seconds

  belongs_to :user
  # FIX CONFIRMED: dependent: :destroy ensures all attendance records are deleted
  # when the list is deleted, preventing foreign key errors.
  has_many :attendance_records, dependent: :destroy
  has_many :students, through: :attendance_records, source: :user

  # FIX CONFIRMED: Uses the new method and attribute name
  before_create :generate_secret_key

  def current_attendance_code
    # Uses secret_key
    totp = ROTP::TOTP.new(secret_key, interval: VALID_PERIOD)
    totp.now
  end

  def verify_attendance_code(code)
    # Uses secret_key
    totp = ROTP::TOTP.new(secret_key, interval: VALID_PERIOD)
    totp.verify(code)
  end

  private

  def generate_secret_key
    # FIX CONFIRMED: Uses the new attribute name 'secret_key'
    self.secret_key = ROTP::Base32.random_base32
  end

  def self.ransackable_attributes(auth_object = nil)
    # FIX CONFIRMED: 'secret_key' replaces 'special_code'
    %w[id title description date user_id created_at updated_at secret_key].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user attendance_records students].freeze
  end
end