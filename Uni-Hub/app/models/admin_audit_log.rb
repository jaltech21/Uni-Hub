class AdminAuditLog < ApplicationRecord
  belongs_to :admin, class_name: 'User', foreign_key: 'admin_id'
  
  # Validations
  validates :action, presence: true
  validates :admin_id, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :for_target, ->(target_type, target_id) { where(target_type: target_type, target_id: target_id) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }
  
  # Methods
  def target
    return nil unless target_type && target_id
    target_type.constantize.find_by(id: target_id)
  end
  
  def action_description
    case action
    when 'create_course' then 'Created course'
    when 'update_course' then 'Updated course'
    when 'delete_course' then 'Deleted course'
    when 'create_schedule' then 'Created schedule'
    when 'update_schedule' then 'Updated schedule'
    when 'delete_schedule' then 'Deleted schedule'
    when 'change_role' then 'Changed user role'
    when 'blacklist_user' then 'Blacklisted user'
    when 'unblacklist_user' then 'Removed user from blacklist'
    when 'update_user' then 'Updated user'
    when 'delete_user' then 'Deleted user'
    else action.humanize
    end
  end
end

