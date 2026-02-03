class ComplianceAssessment < ApplicationRecord
  belongs_to :compliance_framework
  belongs_to :campus, optional: true
  belongs_to :department, optional: true
  belongs_to :assessor, class_name: 'User'
  
  validates :assessment_type, presence: true,
            inclusion: { in: %w[internal external self_assessment peer_review audit] }
  validates :status, presence: true,
            inclusion: { in: %w[scheduled in_progress completed submitted approved rejected] }
  validates :assessment_date, presence: true
  validates :score, numericality: { 
    greater_than_or_equal_to: 0, less_than_or_equal_to: 100 
  }, allow_blank: true
  validates :priority, inclusion: { in: 1..5 }
  
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(assessment_type: type) }
  scope :completed, -> { where(status: 'completed') }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.current, ['completed', 'submitted']) }
  scope :upcoming, -> { where('assessment_date BETWEEN ? AND ?', Date.current, 30.days.from_now) }
  scope :passed, -> { where(passed: true) }
  scope :failed, -> { where(passed: false) }
  scope :recent, ->(days = 30) { where('assessment_date >= ?', days.days.ago) }
  
  before_save :determine_pass_status
  after_update :notify_status_change
  
  def passed?
    passed == true
  end
  
  def failed?
    passed == false
  end
  
  def overdue?
    due_date && due_date < Date.current && !%w[completed submitted].include?(status)
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end
  
  def completion_percentage
    return 0 unless findings.is_a?(Array)
    return 100 if status == 'completed'
    
    total_items = compliance_framework.requirements_checklist.count
    return 0 if total_items.zero?
    
    completed_items = findings.count { |f| f['status'] == 'completed' }
    ((completed_items.to_f / total_items) * 100).round(2)
  end
  
  def findings_summary
    return {} unless findings.is_a?(Array)
    
    summary = { total: findings.count, by_status: {}, by_severity: {} }
    
    findings.each do |finding|
      status = finding['status'] || 'unknown'
      severity = finding['severity'] || 'medium'
      
      summary[:by_status][status] = (summary[:by_status][status] || 0) + 1
      summary[:by_severity][severity] = (summary[:by_severity][severity] || 0) + 1
    end
    
    summary
  end
  
  def critical_findings
    return [] unless findings.is_a?(Array)
    findings.select { |f| f['severity'] == 'critical' }
  end
  
  def action_items_summary
    return {} unless action_items.is_a?(Array)
    
    summary = { total: action_items.count, by_status: {}, overdue: 0 }
    current_date = Date.current.iso8601
    
    action_items.each do |item|
      status = item['status'] || 'pending'
      due_date = item['due_date']
      
      summary[:by_status][status] = (summary[:by_status][status] || 0) + 1
      summary[:overdue] += 1 if due_date && due_date < current_date && status != 'completed'
    end
    
    summary
  end
  
  def add_finding(title, description, severity = 'medium', category = 'general')
    current_findings = findings || []
    current_findings << {
      id: SecureRandom.uuid,
      title: title,
      description: description,
      severity: severity,
      category: category,
      status: 'open',
      created_at: Time.current.iso8601
    }
    update!(findings: current_findings)
  end
  
  def add_recommendation(title, description, priority = 'medium')
    current_recommendations = recommendations || []
    current_recommendations << {
      id: SecureRandom.uuid,
      title: title,
      description: description,
      priority: priority,
      status: 'proposed',
      created_at: Time.current.iso8601
    }
    update!(recommendations: current_recommendations)
  end
  
  def add_action_item(title, description, assignee, due_date)
    current_items = action_items || []
    current_items << {
      id: SecureRandom.uuid,
      title: title,
      description: description,
      assignee: assignee,
      due_date: due_date.iso8601,
      status: 'assigned',
      created_at: Time.current.iso8601
    }
    update!(action_items: current_items)
  end
  
  def complete_assessment!(completion_notes = nil)
    return false unless status == 'in_progress'
    
    update!(
      status: 'completed',
      completion_date: Date.current,
      assessor_notes: [assessor_notes, completion_notes].compact.join("\n")
    )
  end
  
  def submit_for_review!
    return false unless status == 'completed'
    update!(status: 'submitted')
  end
  
  def approve!(approver_notes = nil)
    return false unless status == 'submitted'
    
    update!(
      status: 'approved',
      certification_status: passed? ? 'certified' : 'conditional',
      assessor_notes: [assessor_notes, "Approved: #{approver_notes}"].compact.join("\n")
    )
  end
  
  def assessment_report
    {
      assessment_info: {
        framework: compliance_framework.name,
        type: assessment_type,
        assessor: assessor.email,
        date: assessment_date,
        score: score,
        status: certification_status
      },
      findings: findings_summary,
      recommendations: recommendations&.count || 0,
      action_items: action_items_summary,
      completion: {
        percentage: completion_percentage,
        overdue: overdue?,
        days_overdue: days_overdue
      }
    }
  end
  
  private
  
  def determine_pass_status
    if score.present? && compliance_framework
      threshold = compliance_framework.compliance_threshold
      self.passed = score >= threshold
    end
  end
  
  def notify_status_change
    if status_changed? && status_was.present?
      # Placeholder for notification logic
      puts "Assessment #{id} status changed from #{status_was} to #{status}"
    end
  end
end
