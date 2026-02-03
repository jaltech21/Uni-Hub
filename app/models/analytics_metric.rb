class AnalyticsMetric < ApplicationRecord
  belongs_to :campus, optional: true
  belongs_to :department, optional: true
  belongs_to :user, optional: true
  
  validates :metric_name, presence: true
  validates :metric_type, presence: true, inclusion: { 
    in: %w[performance engagement learning resource compliance system user_behavior financial] 
  }
  validates :entity_type, presence: true
  validates :value, presence: true, numericality: true
  validates :recorded_at, presence: true
  
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :by_entity, ->(entity_type, entity_id) { where(entity_type: entity_type, entity_id: entity_id) }
  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_period, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
  scope :by_campus, ->(campus) { where(campus: campus) }
  scope :by_department, ->(department) { where(department: department) }
  
  # Metric collection methods
  def self.record_user_engagement(user, engagement_type, value, metadata = {})
    create!(
      metric_name: "user_engagement_#{engagement_type}",
      metric_type: 'engagement',
      entity_type: 'User',
      entity_id: user.id,
      value: value,
      metadata: metadata.merge(engagement_type: engagement_type),
      recorded_at: Time.current,
      user: user,
      department: user.department,
      campus: user.department&.campus
    )
  end
  
  def self.record_learning_progress(submission, score, metadata = {})
    create!(
      metric_name: 'learning_progress_score',
      metric_type: 'learning',
      entity_type: 'Submission',
      entity_id: submission.id,
      value: score,
      metadata: metadata.merge(
        assignment_id: submission.assignment_id,
        subject: submission.assignment.title,
        completion_time: submission.submitted_at - submission.assignment.created_at
      ),
      recorded_at: Time.current,
      user: submission.user,
      department: submission.user.department,
      campus: submission.user.department&.campus
    )
  end
  
  def self.record_resource_utilization(resource, utilization_rate, metadata = {})
    create!(
      metric_name: "resource_utilization_#{resource.class.name.downcase}",
      metric_type: 'resource',
      entity_type: resource.class.name,
      entity_id: resource.id,
      value: utilization_rate,
      metadata: metadata.merge(
        resource_name: resource.respond_to?(:name) ? resource.name : "#{resource.class.name} #{resource.id}",
        capacity: resource.respond_to?(:capacity) ? resource.capacity : nil
      ),
      recorded_at: Time.current,
      campus: resource.respond_to?(:campus) ? resource.campus : nil
    )
  end
  
  def self.record_system_performance(endpoint, response_time, metadata = {})
    create!(
      metric_name: 'system_performance_response_time',
      metric_type: 'performance',
      entity_type: 'System',
      entity_id: 0,
      value: response_time,
      metadata: metadata.merge(
        endpoint: endpoint,
        timestamp: Time.current.to_f
      ),
      recorded_at: Time.current
    )
  end
  
  def self.record_compliance_score(framework, score, metadata = {})
    create!(
      metric_name: "compliance_score_#{framework.regulatory_body.parameterize}",
      metric_type: 'compliance',
      entity_type: 'ComplianceFramework',
      entity_id: framework.id,
      value: score,
      metadata: metadata.merge(
        framework_name: framework.name,
        regulatory_body: framework.regulatory_body,
        assessment_id: metadata[:assessment_id]
      ),
      recorded_at: Time.current,
      campus: framework.campus
    )
  end
  
  # Analytics aggregation methods
  def self.average_for_metric(metric_name, period = 30.days)
    where(metric_name: metric_name)
      .where('recorded_at >= ?', period.ago)
      .average(:value) || 0
  end
  
  def self.trend_analysis(metric_name, period = 30.days, interval = 'day')
    metrics = where(metric_name: metric_name)
               .where('recorded_at >= ?', period.ago)
               .order(:recorded_at)
    
    case interval
    when 'hour'
      metrics.group_by_hour(:recorded_at).average(:value)
    when 'day'
      metrics.group_by_day(:recorded_at).average(:value)
    when 'week'
      metrics.group_by_week(:recorded_at).average(:value)
    when 'month'
      metrics.group_by_month(:recorded_at).average(:value)
    else
      metrics.group_by_day(:recorded_at).average(:value)
    end
  end
  
  def self.entity_performance_summary(entity_type, entity_id, period = 30.days)
    metrics = by_entity(entity_type, entity_id)
               .where('recorded_at >= ?', period.ago)
    
    {
      total_metrics: metrics.count,
      metric_types: metrics.group(:metric_type).count,
      average_values: metrics.group(:metric_name).average(:value),
      latest_values: metrics.group(:metric_name).maximum(:value),
      trend_direction: calculate_entity_trend(entity_type, entity_id, period)
    }
  end
  
  def self.calculate_entity_trend(entity_type, entity_id, period = 30.days)
    recent_avg = by_entity(entity_type, entity_id)
                  .where('recorded_at >= ?', (period / 2).ago)
                  .average(:value) || 0
    
    older_avg = by_entity(entity_type, entity_id)
                 .where('recorded_at >= ? AND recorded_at < ?', period.ago, (period / 2).ago)
                 .average(:value) || 0
    
    return 'stable' if older_avg == 0
    
    change_percentage = ((recent_avg - older_avg) / older_avg * 100).round(2)
    
    if change_percentage > 5
      'improving'
    elsif change_percentage < -5
      'declining'
    else
      'stable'
    end
  end
  
  def self.department_comparison(metric_name, period = 30.days)
    where(metric_name: metric_name)
      .where('recorded_at >= ?', period.ago)
      .joins(:department)
      .group('departments.name')
      .average(:value)
      .sort_by { |_, value| -value }
  end
  
  def self.campus_comparison(metric_name, period = 30.days)
    where(metric_name: metric_name)
      .where('recorded_at >= ?', period.ago)
      .joins(:campus)
      .group('campuses.name')
      .average(:value)
      .sort_by { |_, value| -value }
  end
  
  # Real-time analytics
  def self.real_time_summary(metric_type = nil)
    scope = metric_type ? by_type(metric_type) : all
    recent_metrics = scope.where('recorded_at >= ?', 1.hour.ago)
    
    {
      total_events: recent_metrics.count,
      unique_entities: recent_metrics.select(:entity_type, :entity_id).distinct.count,
      average_value: recent_metrics.average(:value)&.round(2) || 0,
      latest_timestamp: recent_metrics.maximum(:recorded_at),
      metric_breakdown: recent_metrics.group(:metric_name).count
    }
  end
  
  def self.anomaly_detection(metric_name, threshold = 2.0)
    metrics = where(metric_name: metric_name).order(:recorded_at).last(100)
    return [] if metrics.count < 10
    
    values = metrics.pluck(:value)
    mean = values.sum.to_f / values.count
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.count
    std_deviation = Math.sqrt(variance)
    
    anomalies = []
    metrics.each do |metric|
      z_score = (metric.value - mean) / std_deviation
      if z_score.abs > threshold
        anomalies << {
          metric: metric,
          z_score: z_score.round(2),
          severity: z_score.abs > 3 ? 'critical' : 'warning'
        }
      end
    end
    
    anomalies
  end
  
  # Data export
  def self.export_metrics(metric_names, start_date, end_date, format = 'csv')
    metrics = where(metric_name: metric_names)
               .where(recorded_at: start_date..end_date)
               .includes(:user, :department, :campus)
               .order(:recorded_at)
    
    case format
    when 'csv'
      generate_csv_export(metrics)
    when 'json'
      metrics.to_json(include: [:user, :department, :campus])
    else
      metrics
    end
  end
  
  private
  
  def self.generate_csv_export(metrics)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Timestamp', 'Metric Name', 'Type', 'Entity', 'Value', 'User', 'Department', 'Campus', 'Metadata']
      
      metrics.each do |metric|
        csv << [
          metric.recorded_at.iso8601,
          metric.metric_name,
          metric.metric_type,
          "#{metric.entity_type}##{metric.entity_id}",
          metric.value,
          metric.user&.full_name,
          metric.department&.name,
          metric.campus&.name,
          metric.metadata.to_json
        ]
      end
    end
  end
end
