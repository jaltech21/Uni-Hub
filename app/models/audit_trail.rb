class AuditTrail < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true
  
  validates :action, presence: true, length: { maximum: 50 }
  validates :severity, inclusion: { in: %w[debug info warn error critical] }
  
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_auditable_type, ->(type) { where(auditable_type: type) }
  scope :security_events, -> { where(security_event: true) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :recent, ->(days = 7) { where('created_at >= ?', days.days.ago) }
  scope :errors, -> { where(severity: ['error', 'critical']) }
  
  def self.log_action(user, auditable, action, details = {})
    create!(
      user: user,
      auditable: auditable,
      action: action,
      change_details: details[:changes] || {},
      metadata: details[:metadata] || {},
      ip_address: details[:ip_address],
      user_agent: details[:user_agent],
      session_id: details[:session_id],
      request_method: details[:request_method],
      request_path: details[:request_path],
      response_status: details[:response_status],
      severity: details[:severity] || 'info',
      security_event: details[:security_event] || false
    )
  end
  
  def self.log_security_event(user, auditable, action, details = {})
    log_action(user, auditable, action, details.merge(security_event: true, severity: 'warn'))
  end
  
  def self.cleanup_old_records(days = 90)
    where('created_at < ?', days.days.ago).delete_all
  end
  
  def security_event?
    security_event == true
  end
  
  def critical?
    severity == 'critical'
  end
  
  def user_display
    user&.email || 'System'
  end
  
  def changes_summary
    return 'No changes recorded' unless change_details.is_a?(Hash)
    
    changes = change_details.map do |field, values|
      if values.is_a?(Array) && values.count == 2
        "#{field}: #{values[0]} → #{values[1]}"
      else
        "#{field}: #{values}"
      end
    end
    
    changes.join(', ')
  end
end
