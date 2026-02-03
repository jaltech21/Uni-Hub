class DashboardWidget < ApplicationRecord
  belongs_to :analytics_dashboard
  
  validates :widget_type, presence: true, inclusion: { 
    in: %w[grade_overview assignment_progress attendance_summary performance_trends 
           class_performance assignment_statistics attendance_analytics student_engagement
           institutional_overview department_comparison user_activity system_health
           usage_statistics grade_distribution upcoming_deadlines recent_submissions],
    message: "%{value} is not a valid widget type" 
  }
  validates :title, presence: true, length: { maximum: 100 }
  validates :position_x, :position_y, :width, :height, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Widget configuration stored as JSON
  serialize :config, JSON
  serialize :data_sources, JSON
  serialize :filter_config, JSON
  
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(widget_type: type) if type.present? }
  scope :ordered, -> { order(:position_y, :position_x) }
  
  # Widget templates for different types
  WIDGET_TEMPLATES = {
    'grade_overview' => {
      title: 'Grade Overview',
      description: 'Student grade summary and trends',
      default_config: {
        chart_type: 'summary_cards',
        show_trend: true,
        time_range: '30_days'
      }
    },
    'assignment_progress' => {
      title: 'Assignment Progress',
      description: 'Current assignment status and deadlines',
      default_config: {
        chart_type: 'progress_bar',
        show_overdue: true,
        limit: 10
      }
    },
    'attendance_summary' => {
      title: 'Attendance Summary',
      description: 'Class attendance rates and patterns',
      default_config: {
        chart_type: 'donut_chart',
        show_percentage: true,
        time_range: '30_days'
      }
    },
    'performance_trends' => {
      title: 'Performance Trends',
      description: 'Grade performance over time',
      default_config: {
        chart_type: 'line_chart',
        show_average: true,
        time_range: '90_days'
      }
    },
    'class_performance' => {
      title: 'Class Performance',
      description: 'Overall class statistics and metrics',
      default_config: {
        chart_type: 'mixed_chart',
        show_distribution: true,
        compare_periods: true
      }
    },
    'assignment_statistics' => {
      title: 'Assignment Statistics',
      description: 'Assignment creation and submission metrics',
      default_config: {
        chart_type: 'bar_chart',
        show_completion_rate: true,
        group_by: 'week'
      }
    },
    'attendance_analytics' => {
      title: 'Attendance Analytics',
      description: 'Detailed attendance patterns and insights',
      default_config: {
        chart_type: 'heatmap',
        show_late_arrivals: true,
        time_range: '60_days'
      }
    },
    'student_engagement' => {
      title: 'Student Engagement',
      description: 'Student participation and engagement metrics',
      default_config: {
        chart_type: 'scatter_plot',
        show_top_performers: true,
        engagement_threshold: 70
      }
    }
  }.freeze
  
  def self.create_from_template(dashboard, widget_type, position = {})
    template = WIDGET_TEMPLATES[widget_type]
    return nil unless template
    
    create!(
      analytics_dashboard: dashboard,
      widget_type: widget_type,
      title: template[:title],
      description: template[:description],
      config: template[:default_config],
      position_x: position[:x] || 0,
      position_y: position[:y] || 0,
      width: position[:w] || 4,
      height: position[:h] || 3,
      active: true
    )
  end
  
  # Get widget data based on configuration
  def widget_data(time_range: nil)
    time_range ||= parse_time_range(config&.dig('time_range') || '30_days')
    
    base_data = analytics_dashboard.send(:generate_widget_data, widget_type, time_range)
    
    # Apply widget-specific configuration
    apply_widget_config(base_data)
  end
  
  # Update widget position and size
  def update_position(x:, y:, width:, height:)
    update!(
      position_x: x,
      position_y: y,
      width: width,
      height: height
    )
  end
  
  # Update widget configuration
  def update_config(new_config)
    self.config = (config || {}).merge(new_config)
    save!
  end
  
  # Check if widget is available for user role
  def available_for_role?(role)
    case widget_type
    when 'grade_overview', 'assignment_progress', 'attendance_summary', 'performance_trends'
      %w[student teacher admin].include?(role)
    when 'class_performance', 'assignment_statistics', 'attendance_analytics', 'student_engagement'
      %w[teacher admin].include?(role)
    when 'institutional_overview', 'department_comparison', 'user_activity', 'system_health', 'usage_statistics'
      %w[admin].include?(role)
    else
      false
    end
  end
  
  # Get chart configuration for frontend
  def chart_config
    base_config = {
      type: config&.dig('chart_type') || 'bar_chart',
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: config&.dig('show_legend') != false,
          position: config&.dig('legend_position') || 'top'
        },
        tooltip: {
          enabled: config&.dig('show_tooltips') != false
        }
      }
    }
    
    # Add widget-specific configuration
    case widget_type
    when 'performance_trends'
      base_config[:scales] = {
        y: {
          beginAtZero: true,
          max: 100,
          title: { display: true, text: 'Grade (%)' }
        },
        x: {
          title: { display: true, text: 'Time Period' }
        }
      }
    when 'attendance_summary'
      if config&.dig('chart_type') == 'donut_chart'
        base_config[:cutout] = '50%'
      end
    when 'grade_distribution'
      base_config[:scales] = {
        y: {
          beginAtZero: true,
          title: { display: true, text: 'Number of Students' }
        }
      }
    end
    
    base_config
  end
  
  # Export widget data for reports
  def export_data(format: 'json')
    data = widget_data
    
    case format.to_s
    when 'csv'
      to_csv(data)
    when 'excel'
      to_excel(data)
    else
      data.to_json
    end
  end
  
  private
  
  def parse_time_range(range_string)
    case range_string
    when '7_days'
      7.days
    when '30_days'
      30.days
    when '90_days'
      90.days
    when '180_days'
      180.days
    when '1_year'
      1.year
    else
      30.days
    end
  end
  
  def apply_widget_config(base_data)
    # Apply filters and transformations based on widget configuration
    filtered_data = base_data.dup
    
    # Apply limit if specified
    if config&.dig('limit')
      limit = config['limit'].to_i
      filtered_data.each do |key, value|
        if value.is_a?(Array) && value.length > limit
          filtered_data[key] = value.first(limit)
        end
      end
    end
    
    # Apply sorting if specified
    if config&.dig('sort_by')
      sort_field = config['sort_by']
      sort_order = config&.dig('sort_order') || 'desc'
      
      filtered_data.each do |key, value|
        if value.is_a?(Array) && value.first.is_a?(Hash) && value.first.key?(sort_field.to_sym)
          filtered_data[key] = value.sort_by { |item| item[sort_field.to_sym] }
          filtered_data[key].reverse! if sort_order == 'desc'
        end
      end
    end
    
    # Apply threshold filters if specified
    if config&.dig('threshold')
      threshold = config['threshold'].to_f
      threshold_field = config&.dig('threshold_field') || 'value'
      
      filtered_data.each do |key, value|
        if value.is_a?(Array) && value.first.is_a?(Hash)
          filtered_data[key] = value.select { |item| item[threshold_field.to_sym].to_f >= threshold }
        end
      end
    end
    
    filtered_data
  end
  
  def to_csv(data)
    require 'csv'
    
    CSV.generate do |csv|
      # Add headers
      if data.is_a?(Hash) && data.values.first.is_a?(Array) && data.values.first.first.is_a?(Hash)
        headers = data.values.first.first.keys
        csv << headers
        
        data.each do |category, items|
          items.each do |item|
            csv << headers.map { |header| item[header] }
          end
        end
      else
        csv << ['Category', 'Value']
        data.each do |key, value|
          csv << [key, value]
        end
      end
    end
  end
  
  def to_excel(data)
    # This would require axlsx gem or similar
    # For now, return CSV format
    to_csv(data)
  end
end