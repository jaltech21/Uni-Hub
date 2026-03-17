class DepartmentMemberHistory < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :department
  belongs_to :performed_by, class_name: 'User', optional: true
  
  # Validations
  validates :action, presence: true
  validates :action, inclusion: { 
    in: %w[added removed role_changed status_changed imported transferred],
    message: "%{value} is not a valid action"
  }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_department, ->(dept_id) { where(department_id: dept_id) }
  scope :by_action, ->(action) { where(action: action) }
  
  # Class methods
  def self.log_addition(user, department, performed_by, details = {})
    create!(
      user: user,
      department: department,
      action: 'added',
      performed_by: performed_by,
      details: details
    )
  end
  
  def self.log_removal(user, department, performed_by, details = {})
    create!(
      user: user,
      department: department,
      action: 'removed',
      performed_by: performed_by,
      details: details
    )
  end
  
  def self.log_role_change(user, department, performed_by, old_role, new_role)
    create!(
      user: user,
      department: department,
      action: 'role_changed',
      performed_by: performed_by,
      details: { old_role: old_role, new_role: new_role }
    )
  end
  
  def self.log_status_change(user, department, performed_by, old_status, new_status)
    create!(
      user: user,
      department: department,
      action: 'status_changed',
      performed_by: performed_by,
      details: { old_status: old_status, new_status: new_status }
    )
  end
  
  def self.log_import(users, department, performed_by, import_details = {})
    users.each do |user|
      create!(
        user: user,
        department: department,
        action: 'imported',
        performed_by: performed_by,
        details: import_details
      )
    end
  end
  
  # Instance methods
  def description
    case action
    when 'added'
      "#{user.full_name} was added to #{department.name}"
    when 'removed'
      "#{user.full_name} was removed from #{department.name}"
    when 'role_changed'
      "#{user.full_name}'s role changed from #{details['old_role']} to #{details['new_role']}"
    when 'status_changed'
      "#{user.full_name}'s status changed from #{details['old_status']} to #{details['new_status']}"
    when 'imported'
      "#{user.full_name} was imported to #{department.name}"
    when 'transferred'
      from_dept = details['from_department'] || 'unknown'
      "#{user.full_name} was transferred from #{from_dept} to #{department.name}"
    else
      "#{action} performed on #{user.full_name}"
    end
  end
end
