class ComplianceFramework < ApplicationRecord
  # Associations
  has_many :compliance_assessments, dependent: :destroy
  has_many :compliance_reports, dependent: :destroy
  
  validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
  validates :framework_type, presence: true,
            inclusion: { in: %w[accreditation quality_assurance data_protection 
                               financial_reporting student_records accessibility 
                               safety_compliance research_ethics] }
  validates :regulatory_body, presence: true, length: { maximum: 255 }
  validates :reporting_frequency, presence: true,
            inclusion: { in: %w[monthly quarterly semi_annual annual biennial] }
  validates :status, presence: true,
            inclusion: { in: %w[active inactive pending_approval deprecated] }
  validates :compliance_threshold, numericality: { 
    greater_than_or_equal_to: 0, less_than_or_equal_to: 100 
  }
  
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(framework_type: type) }
  scope :mandatory, -> { where(mandatory: true) }
  scope :due_for_assessment, -> { 
    where('effective_date + INTERVAL assessment_cycle_months MONTH <= ?', Date.current) 
  }
  scope :expiring_soon, -> { 
    where('expiry_date IS NOT NULL AND expiry_date BETWEEN ? AND ?', 
          Date.current, 90.days.from_now) 
  }
  
  def active?
    status == 'active'
  end
  
  def mandatory?
    mandatory == true
  end
  
  def expired?
    expiry_date.present? && expiry_date < Date.current
  end
  
  def next_assessment_due
    return nil unless effective_date && assessment_cycle_months
    effective_date + assessment_cycle_months.months
  end
  
  def days_until_assessment
    return nil unless next_assessment_due
    (next_assessment_due - Date.current).to_i
  end
  
  def assessment_overdue?
    next_assessment_due && next_assessment_due < Date.current
  end
  
  def current_compliance_status
    recent_assessment = compliance_assessments
                       .where('assessment_date >= ?', assessment_cycle_months.months.ago)
                       .order(:assessment_date)
                       .last
    
    return 'no_assessment' unless recent_assessment
    return 'compliant' if recent_assessment.passed?
    'non_compliant'
  end
  
  def compliance_history(limit = 10)
    compliance_assessments.order(assessment_date: :desc).limit(limit)
  end
  
  def compliance_trend(months = 12)
    assessments = compliance_assessments
                 .where('assessment_date >= ?', months.months.ago)
                 .order(:assessment_date)
    
    assessments.map { |a| { date: a.assessment_date, score: a.score, passed: a.passed? } }
  end
  
  def average_compliance_score(months = 12)
    scores = compliance_assessments
             .where('assessment_date >= ?', months.months.ago)
             .where.not(score: nil)
             .pluck(:score)
    
    return 0 if scores.empty?
    (scores.sum / scores.count).round(2)
  end
  
  def requirements_checklist
    return [] unless requirements.is_a?(Array)
    
    requirements.map do |req|
      {
        id: req['id'],
        title: req['title'],
        description: req['description'],
        mandatory: req['mandatory'] || false,
        category: req['category'],
        verification_method: req['verification_method']
      }
    end
  end
  
  def assessment_criteria_summary
    return {} unless assessment_criteria.is_a?(Hash)
    
    {
      total_criteria: assessment_criteria.keys.count,
      categories: assessment_criteria.keys,
      scoring_method: assessment_criteria['scoring_method'] || 'weighted',
      max_score: assessment_criteria['max_score'] || 100
    }
  end
  
  def notification_schedule
    settings = notification_settings || {}
    {
      assessment_reminder_days: settings['assessment_reminder_days'] || [30, 14, 7],
      report_due_days: settings['report_due_days'] || [15, 7, 1],
      compliance_alerts: settings['compliance_alerts'] != false
    }
  end
  
  def self.due_for_assessment_notification
    active.select do |framework|
      days_until = framework.days_until_assessment
      next unless days_until
      
      reminder_days = framework.notification_schedule[:assessment_reminder_days]
      reminder_days.include?(days_until) || days_until <= 0
    end
  end
end
