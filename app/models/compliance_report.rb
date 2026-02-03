class ComplianceReport < ApplicationRecord
  belongs_to :compliance_framework
  belongs_to :campus, optional: true
  belongs_to :generated_by, class_name: 'User'
  
  validates :report_type, presence: true,
            inclusion: { in: %w[assessment_summary compliance_status trend_analysis 
                               regulatory_submission annual_report quarterly_report] }
  validates :status, presence: true,
            inclusion: { in: %w[draft in_progress completed published archived] }
  validates :period_start, :period_end, presence: true
  validates :report_format, inclusion: { in: %w[pdf html csv json] }
  validate :period_end_after_start
  
  scope :by_type, ->(type) { where(report_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
  scope :auto_generated, -> { where(auto_generated: true) }
  scope :for_period, ->(start_date, end_date) { 
    where('period_start >= ? AND period_end <= ?', start_date, end_date) 
  }
  
  before_create :generate_default_content
  after_update :handle_publication
  
  def period_description
    "#{period_start.strftime('%b %Y')} - #{period_end.strftime('%b %Y')}"
  end
  
  def published?
    status == 'published'
  end
  
  def draft?
    status == 'draft'
  end
  
  def can_be_published?
    status == 'completed' && executive_summary.present?
  end
  
  def publish!(publisher = nil)
    return false unless can_be_published?
    
    update!(
      status: 'published',
      published_at: Time.current,
      generated_by: publisher || generated_by
    )
  end
  
  def compliance_score_trend
    return [] unless content.is_a?(Hash) && content['trend_data']
    content['trend_data']
  end
  
  def key_findings
    return [] unless content.is_a?(Hash) && content['key_findings']
    content['key_findings']
  end
  
  def generate_executive_summary!
    assessments = compliance_framework.compliance_assessments
                                    .where(assessment_date: period_start..period_end)
    
    total_assessments = assessments.count
    passed_assessments = assessments.passed.count
    avg_score = assessments.average(:score) || 0
    
    summary = []
    summary << "During #{period_description}, #{total_assessments} compliance assessments were conducted."
    summary << "#{passed_assessments} assessments (#{percentage(passed_assessments, total_assessments)}%) achieved passing status."
    summary << "The average compliance score was #{avg_score.round(2)}%."
    
    if total_assessments > 0
      compliance_rate = (passed_assessments.to_f / total_assessments * 100).round(2)
      threshold = compliance_framework.compliance_threshold
      
      if compliance_rate >= threshold
        summary << "The overall compliance rate of #{compliance_rate}% meets the required threshold of #{threshold}%."
      else
        summary << "The overall compliance rate of #{compliance_rate}% falls below the required threshold of #{threshold}%."
        summary << "Immediate action is required to address compliance gaps."
      end
    end
    
    update!(executive_summary: summary.join(' '))
  end
  
  def generate_content!
    assessments = compliance_framework.compliance_assessments
                                    .where(assessment_date: period_start..period_end)
                                    .includes(:campus, :department, :assessor)
    
    report_content = {
      summary: {
        total_assessments: assessments.count,
        passed_assessments: assessments.passed.count,
        failed_assessments: assessments.failed.count,
        average_score: assessments.average(:score)&.round(2) || 0,
        compliance_rate: calculate_compliance_rate(assessments)
      },
      assessments_by_type: assessments.group(:assessment_type).count,
      assessments_by_campus: assessments.joins(:campus).group('campuses.name').count,
      trend_data: generate_trend_data(assessments),
      key_findings: extract_key_findings(assessments),
      recommendations: consolidate_recommendations(assessments),
      action_items: extract_action_items(assessments)
    }
    
    update!(
      content: report_content,
      overall_compliance_score: report_content[:summary][:average_score],
      total_assessments: report_content[:summary][:total_assessments],
      passed_assessments: report_content[:summary][:passed_assessments],
      key_metrics: {
        compliance_rate: report_content[:summary][:compliance_rate],
        improvement_needed: report_content[:summary][:failed_assessments],
        trend_direction: calculate_trend_direction
      }
    )
    
    generate_executive_summary!
  end
  
  def export_to_pdf
    # Placeholder for PDF generation
    # This would typically use a gem like Prawn or wicked_pdf
    {
      success: true,
      file_path: "reports/compliance_report_#{id}.pdf",
      message: "Report exported successfully"
    }
  end
  
  def export_to_csv
    # Placeholder for CSV export
    {
      success: true,
      file_path: "reports/compliance_report_#{id}.csv",
      message: "Report exported successfully"
    }
  end
  
  def self.generate_automated_report(framework, report_type = 'quarterly')
    end_date = Date.current
    start_date = case report_type
                 when 'monthly' then end_date.beginning_of_month
                 when 'quarterly' then end_date.beginning_of_quarter
                 when 'annual' then end_date.beginning_of_year
                 else 3.months.ago
                 end
    
    report = create!(
      compliance_framework: framework,
      report_type: report_type,
      period_start: start_date,
      period_end: end_date,
      generated_by: User.find_by(role: 'system') || User.first,
      status: 'draft',
      auto_generated: true
    )
    
    report.generate_content!
    report.update!(status: 'completed')
    report
  end
  
  private
  
  def period_end_after_start
    return unless period_start && period_end
    errors.add(:period_end, 'must be after period start') if period_end <= period_start
  end
  
  def generate_default_content
    self.content ||= {
      summary: {},
      assessments: [],
      findings: [],
      recommendations: []
    }
  end
  
  def handle_publication
    if status_changed? && status == 'published'
      # Send notifications, update stakeholders, etc.
      puts "Compliance report #{id} has been published"
    end
  end
  
  def calculate_compliance_rate(assessments)
    return 0 if assessments.empty?
    (assessments.passed.count.to_f / assessments.count * 100).round(2)
  end
  
  def generate_trend_data(assessments)
    assessments.group_by_month(:assessment_date)
               .average(:score)
               .map { |month, avg_score| { month: month, score: avg_score&.round(2) || 0 } }
  end
  
  def extract_key_findings(assessments)
    all_findings = []
    
    assessments.each do |assessment|
      next unless assessment.findings.is_a?(Array)
      
      critical_findings = assessment.findings.select { |f| f['severity'] == 'critical' }
      all_findings.concat(critical_findings)
    end
    
    all_findings.uniq { |f| f['title'] }.first(10)
  end
  
  def consolidate_recommendations(assessments)
    all_recommendations = []
    
    assessments.each do |assessment|
      next unless assessment.recommendations.is_a?(Array)
      all_recommendations.concat(assessment.recommendations)
    end
    
    # Group similar recommendations
    all_recommendations.group_by { |r| r['title'] }
                      .map { |title, recs| { title: title, count: recs.count, priority: recs.first['priority'] } }
                      .sort_by { |r| priority_weight(r[:priority]) }
                      .reverse
                      .first(15)
  end
  
  def extract_action_items(assessments)
    all_items = []
    
    assessments.each do |assessment|
      next unless assessment.action_items.is_a?(Array)
      
      overdue_items = assessment.action_items.select do |item|
        item['due_date'] && Date.parse(item['due_date']) < Date.current && item['status'] != 'completed'
      end
      
      all_items.concat(overdue_items)
    end
    
    all_items.first(20)
  end
  
  def calculate_trend_direction
    return 'stable' unless content.is_a?(Hash) && content['trend_data']
    
    trend_data = content['trend_data']
    return 'stable' if trend_data.count < 2
    
    recent_scores = trend_data.last(3).map { |d| d[:score] }
    return 'stable' if recent_scores.count < 2
    
    if recent_scores.last > recent_scores.first
      'improving'
    elsif recent_scores.last < recent_scores.first
      'declining'
    else
      'stable'
    end
  end
  
  def priority_weight(priority)
    case priority
    when 'critical' then 5
    when 'high' then 4
    when 'medium' then 3
    when 'low' then 2
    else 1
    end
  end
  
  def percentage(part, total)
    return 0 if total.zero?
    ((part.to_f / total) * 100).round(1)
  end
end
