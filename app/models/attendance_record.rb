class AttendanceRecord < ApplicationRecord
  belongs_to :attendance_list
  belongs_to :user

  # Ransack allowlist for ActiveAdmin searches
  def self.ransackable_attributes(auth_object = nil)
    %w[id attendance_list_id user_id present created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[attendance_list user].freeze
  end
end
