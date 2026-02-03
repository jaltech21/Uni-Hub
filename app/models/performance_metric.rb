class PerformanceMetric < ApplicationRecord
  validates :metric_type, presence: true, inclusion: {
    in: %w[response_time memory_usage cpu_usage database_query api_endpoint 
           user_action page_load system_health background_job]
  }
  validates :recorded_at, presence: true
  validates :response_time, numericality: { greater_than: 0 }, allow_nil: true
  validates :memory_usage, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cpu_usage, numericality: { in: 0..100 }, allow_nil: true
  
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :by_endpoint, ->(endpoint) { where(endpoint_path: endpoint) }
  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_period, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
  scope :slow_requests, -> { where('response_time > ?', 2000) } # > 2 seconds
  scope :high_memory, -> { where('memory_usage > ?', 100) } # > 100MB
  scope :high_cpu, -> { where('cpu_usage > ?', 80) } # > 80%
  scope :with_errors, -> { where('error_count > 0') }
  
  # Performance monitoring methods
  def self.record_request_performance(endpoint, response_time, metadata = {})
    create!(
      metric_type: 'response_time',
      endpoint_path: endpoint,
      response_time: response_time,
      memory_usage: metadata[:memory_usage],
      cpu_usage: metadata[:cpu_usage],
      query_count: metadata[:query_count] || 0,
      error_count: metadata[:error_count] || 0,
      optimization_suggestions: generate_optimization_suggestions(endpoint, response_time, metadata),
      recorded_at: Time.current
    )
  end
  
  def self.record_database_performance(query_type, execution_time, query_count = 1)
    create!(
      metric_type: 'database_query',
      endpoint_path: query_type,
      response_time: execution_time,
      query_count: query_count,
      optimization_suggestions: generate_db_optimization_suggestions(query_type, execution_time, query_count),
      recorded_at: Time.current
    )
  end
  
  def self.record_system_health(cpu_usage, memory_usage, metadata = {})
    create!(
      metric_type: 'system_health',
      cpu_usage: cpu_usage,
      memory_usage: memory_usage,
      optimization_suggestions: generate_system_optimization_suggestions(cpu_usage, memory_usage, metadata),
      recorded_at: Time.current
    )
  end
  
  def self.record_user_action(action_type, response_time, user_id = nil)
    create!(
      metric_type: 'user_action',
      endpoint_path: action_type,
      response_time: response_time,
      optimization_suggestions: generate_ux_optimization_suggestions(action_type, response_time),
      recorded_at: Time.current
    )
  end
  
  # Analytics and reporting methods
  def self.performance_summary(period = 30.days)
    metrics = where('recorded_at >= ?', period.ago)
    
    {
      total_requests: metrics.count,
      average_response_time: metrics.average(:response_time)&.round(2) || 0,
      median_response_time: calculate_median_response_time(metrics),
      p95_response_time: calculate_percentile_response_time(metrics, 95),
      p99_response_time: calculate_percentile_response_time(metrics, 99),
      slow_requests: metrics.slow_requests.count,
      error_rate: calculate_error_rate(metrics),
      average_memory_usage: metrics.average(:memory_usage)&.round(2) || 0,
      average_cpu_usage: metrics.average(:cpu_usage)&.round(2) || 0,
      total_database_queries: metrics.sum(:query_count)
    }
  end
  
  def self.endpoint_performance_analysis(period = 7.days)
    metrics = where('recorded_at >= ?', period.ago)
               .where.not(endpoint_path: nil)
    
    endpoint_stats = metrics.group(:endpoint_path)
                           .select(
                             'endpoint_path,
                              COUNT(*) as request_count,
                              AVG(response_time) as avg_response_time,
                              MAX(response_time) as max_response_time,
                              SUM(error_count) as total_errors'
                           )
    
    endpoint_stats.map do |stat|
      {
        endpoint: stat.endpoint_path,
        request_count: stat.request_count,
        avg_response_time: stat.avg_response_time&.round(2) || 0,
        max_response_time: stat.max_response_time || 0,
        error_count: stat.total_errors || 0,
        performance_grade: calculate_endpoint_grade(stat.avg_response_time, stat.total_errors, stat.request_count)
      }
    end.sort_by { |stat| -stat[:avg_response_time] }
  end
  
  def self.identify_performance_bottlenecks(threshold_percentile = 95)
    recent_metrics = where('recorded_at >= ?', 24.hours.ago)
    
    bottlenecks = []
    
    # Response time bottlenecks
    slow_threshold = calculate_percentile_response_time(recent_metrics, threshold_percentile)
    slow_endpoints = recent_metrics.where('response_time > ?', slow_threshold)
                                  .group(:endpoint_path)
                                  .count
    
    slow_endpoints.each do |endpoint, count|
      bottlenecks << {
        type: 'response_time',
        endpoint: endpoint,
        issue: 'High response time',
        severity: count > 10 ? 'critical' : 'warning',
        occurrences: count,
        recommendation: "Optimize #{endpoint} endpoint - consider caching, database optimization, or code refactoring"
      }
    end
    
    # Memory usage bottlenecks
    high_memory_endpoints = recent_metrics.high_memory
                                         .group(:endpoint_path)
                                         .count
    
    high_memory_endpoints.each do |endpoint, count|
      bottlenecks << {
        type: 'memory_usage',
        endpoint: endpoint,
        issue: 'High memory consumption',
        severity: count > 5 ? 'critical' : 'warning',
        occurrences: count,
        recommendation: "Review memory usage in #{endpoint} - check for memory leaks or inefficient data processing"
      }
    end
    
    # Database query bottlenecks
    high_query_endpoints = recent_metrics.where('query_count > 20')
                                        .group(:endpoint_path)
                                        .count
    
    high_query_endpoints.each do |endpoint, count|
      bottlenecks << {
        type: 'database_queries',
        endpoint: endpoint,
        issue: 'Excessive database queries',
        severity: count > 3 ? 'critical' : 'warning',
        occurrences: count,
        recommendation: "Implement query optimization for #{endpoint} - consider eager loading, indexing, or query consolidation"
      }
    end
    
    bottlenecks.sort_by { |b| [b[:severity] == 'critical' ? 0 : 1, -b[:occurrences]] }
  end
  
  def self.generate_optimization_report(period = 7.days)
    metrics = where('recorded_at >= ?', period.ago)
    summary = performance_summary(period)
    bottlenecks = identify_performance_bottlenecks
    endpoint_analysis = endpoint_performance_analysis(period)
    
    {
      report_period: period,
      generated_at: Time.current,
      performance_summary: summary,
      bottlenecks: bottlenecks,
      endpoint_analysis: endpoint_analysis,
      recommendations: generate_global_recommendations(summary, bottlenecks),
      health_score: calculate_system_health_score(summary, bottlenecks)
    }
  end
  
  def self.real_time_alerts
    alerts = []
    recent_metrics = where('recorded_at >= ?', 5.minutes.ago)
    
    # Response time alerts
    if recent_metrics.where('response_time > 5000').exists?
      alerts << {
        type: 'critical',
        message: 'Extremely slow response times detected (>5s)',
        action_required: 'Immediate investigation required'
      }
    end
    
    # Error rate alerts
    error_rate = calculate_error_rate(recent_metrics)
    if error_rate > 5
      alerts << {
        type: 'warning',
        message: "High error rate detected: #{error_rate.round(2)}%",
        action_required: 'Review recent deployments and error logs'
      }
    end
    
    # System resource alerts
    if recent_metrics.where('cpu_usage > 90').exists?
      alerts << {
        type: 'critical',
        message: 'High CPU usage detected (>90%)',
        action_required: 'Check system load and running processes'
      }
    end
    
    alerts
  end
  
  private
  
  def self.generate_optimization_suggestions(endpoint, response_time, metadata)
    suggestions = []
    
    if response_time > 2000
      suggestions << 'Consider implementing caching for this endpoint'
      suggestions << 'Review database queries for optimization opportunities'
    end
    
    if metadata[:query_count] && metadata[:query_count] > 10
      suggestions << 'Reduce number of database queries through eager loading'
      suggestions << 'Consider implementing query batching'
    end
    
    if metadata[:memory_usage] && metadata[:memory_usage] > 100
      suggestions << 'Optimize memory usage - check for unnecessary data loading'
      suggestions << 'Implement pagination for large datasets'
    end
    
    suggestions
  end
  
  def self.generate_db_optimization_suggestions(query_type, execution_time, query_count)
    suggestions = []
    
    if execution_time > 1000
      suggestions << 'Add appropriate database indexes'
      suggestions << 'Consider query optimization or rewriting'
    end
    
    if query_count > 50
      suggestions << 'Implement query batching'
      suggestions << 'Consider using database views for complex queries'
    end
    
    suggestions
  end
  
  def self.generate_system_optimization_suggestions(cpu_usage, memory_usage, metadata)
    suggestions = []
    
    if cpu_usage > 80
      suggestions << 'Consider scaling up server resources'
      suggestions << 'Optimize CPU-intensive operations'
    end
    
    if memory_usage > 80
      suggestions << 'Implement memory optimization strategies'
      suggestions << 'Consider increasing server memory or optimizing memory usage'
    end
    
    suggestions
  end
  
  def self.calculate_median_response_time(metrics)
    response_times = metrics.where.not(response_time: nil).pluck(:response_time).sort
    return 0 if response_times.empty?
    
    mid = response_times.length / 2
    response_times.length.odd? ? response_times[mid] : (response_times[mid - 1] + response_times[mid]) / 2.0
  end
  
  def self.calculate_percentile_response_time(metrics, percentile)
    response_times = metrics.where.not(response_time: nil).pluck(:response_time).sort
    return 0 if response_times.empty?
    
    index = (percentile / 100.0 * (response_times.length - 1)).round
    response_times[index]
  end
  
  def self.calculate_error_rate(metrics)
    total_requests = metrics.count
    return 0 if total_requests == 0
    
    requests_with_errors = metrics.where('error_count > 0').count
    (requests_with_errors.to_f / total_requests * 100).round(2)
  end
  
  def self.calculate_endpoint_grade(avg_response_time, error_count, request_count)
    score = 100
    
    # Deduct points for slow response times
    if avg_response_time > 2000
      score -= 30
    elsif avg_response_time > 1000
      score -= 15
    elsif avg_response_time > 500
      score -= 5
    end
    
    # Deduct points for errors
    error_rate = request_count > 0 ? (error_count.to_f / request_count * 100) : 0
    score -= (error_rate * 2).round
    
    case score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end
  
  def self.calculate_system_health_score(summary, bottlenecks)
    score = 100
    
    # Deduct for slow response times
    if summary[:average_response_time] > 2000
      score -= 20
    elsif summary[:average_response_time] > 1000
      score -= 10
    end
    
    # Deduct for high error rate
    score -= (summary[:error_rate] * 2).round if summary[:error_rate]
    
    # Deduct for critical bottlenecks
    critical_bottlenecks = bottlenecks.count { |b| b[:severity] == 'critical' }
    score -= (critical_bottlenecks * 10)
    
    # Deduct for warning bottlenecks
    warning_bottlenecks = bottlenecks.count { |b| b[:severity] == 'warning' }
    score -= (warning_bottlenecks * 5)
    
    [score, 0].max
  end
end
