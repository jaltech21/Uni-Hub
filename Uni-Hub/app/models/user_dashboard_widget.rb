# app/models/user_dashboard_widget.rb
class UserDashboardWidget < ApplicationRecord
  belongs_to :user
  
  # Available widget types
  WIDGET_TYPES = {
    'recent_activity' => 'Recent Activity',
    'quick_stats' => 'Quick Stats',
    'upcoming_deadlines' => 'Upcoming Deadlines',
    'recent_notes' => 'Recent Notes',
    'assignment_progress' => 'Assignment Progress',
    'communication_overview' => 'Communication',
    'calendar_preview' => 'Calendar Preview',
    'grade_overview' => 'Grade Overview',
    'discussion_feed' => 'Discussion Feed',
    'learning_insights' => 'Learning Insights',
    'weather' => 'Weather',
    'quick_actions' => 'Quick Actions'
  }.freeze
  
  # Validation
  validates :widget_type, presence: true, inclusion: { in: WIDGET_TYPES.keys }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :width, presence: true, numericality: { in: 1..12 }
  validates :height, presence: true, numericality: { in: 1..8 }
  validates :grid_x, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :grid_y, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :active, -> { where(enabled: true) }
  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:position) }
  scope :by_grid_position, -> { order(:grid_y, :grid_x) }
  
  # Callbacks
  before_validation :set_defaults
  after_initialize :set_default_configuration
  
  # Class methods
  def self.available_widgets
    WIDGET_TYPES
  end
  
  def self.default_widgets_for_user(user)
    defaults = case user.role
    when 'student'
      [
        { widget_type: 'quick_stats', position: 0, grid_x: 0, grid_y: 0, width: 6, height: 2 },
        { widget_type: 'upcoming_deadlines', position: 1, grid_x: 6, grid_y: 0, width: 6, height: 2 },
        { widget_type: 'recent_notes', position: 2, grid_x: 0, grid_y: 2, width: 4, height: 3 },
        { widget_type: 'assignment_progress', position: 3, grid_x: 4, grid_y: 2, width: 4, height: 3 },
        { widget_type: 'communication_overview', position: 4, grid_x: 8, grid_y: 2, width: 4, height: 3 },
        { widget_type: 'recent_activity', position: 5, grid_x: 0, grid_y: 5, width: 12, height: 2 }
      ]
    when 'teacher', 'tutor'
      [
        { widget_type: 'quick_stats', position: 0, grid_x: 0, grid_y: 0, width: 4, height: 2 },
        { widget_type: 'grade_overview', position: 1, grid_x: 4, grid_y: 0, width: 4, height: 2 },
        { widget_type: 'upcoming_deadlines', position: 2, grid_x: 8, grid_y: 0, width: 4, height: 2 },
        { widget_type: 'assignment_progress', position: 3, grid_x: 0, grid_y: 2, width: 6, height: 3 },
        { widget_type: 'communication_overview', position: 4, grid_x: 6, grid_y: 2, width: 6, height: 3 },
        { widget_type: 'discussion_feed', position: 5, grid_x: 0, grid_y: 5, width: 8, height: 3 },
        { widget_type: 'learning_insights', position: 6, grid_x: 8, grid_y: 5, width: 4, height: 3 }
      ]
    else # admin
      [
        { widget_type: 'quick_stats', position: 0, grid_x: 0, grid_y: 0, width: 3, height: 2 },
        { widget_type: 'recent_activity', position: 1, grid_x: 3, grid_y: 0, width: 9, height: 2 },
        { widget_type: 'communication_overview', position: 2, grid_x: 0, grid_y: 2, width: 6, height: 3 },
        { widget_type: 'learning_insights', position: 3, grid_x: 6, grid_y: 2, width: 6, height: 3 }
      ]
    end
    
    defaults
  end
  
  def self.create_default_widgets_for_user(user)
    return if user.dashboard_widgets.exists?
    
    default_widgets = default_widgets_for_user(user)
    
    default_widgets.each do |widget_config|
      user.dashboard_widgets.create!(widget_config)
    end
  end
  
  # Instance methods
  def display_title
    title.present? ? title : WIDGET_TYPES[widget_type]
  end
  
  def needs_refresh?
    return true if last_refreshed.nil?
    last_refreshed < refresh_interval.seconds.ago
  end
  
  def refresh_data!
    update!(last_refreshed: Time.current)
  end
  
  def configuration_with_defaults
    default_config = default_configuration_for_type
    default_config.merge(configuration || {})
  end
  
  def can_be_edited_by?(current_user)
    user == current_user
  end
  
  def grid_position
    { x: grid_x, y: grid_y }
  end
  
  def grid_size
    { width: width, height: height }
  end
  
  private
  
  def set_defaults
    self.title ||= WIDGET_TYPES[widget_type] if widget_type.present?
    self.position ||= (user&.user_dashboard_widgets&.maximum(:position) || -1) + 1
    self.enabled = true if enabled.nil?
    self.refresh_interval ||= 300
  end
  
  def set_default_configuration
    self.configuration ||= {}
  end
  
  def default_configuration_for_type
    case widget_type
    when 'recent_activity'
      { 'limit' => 10, 'show_avatars' => true, 'compact_view' => false }
    when 'quick_stats'
      { 'show_charts' => true, 'animation' => true, 'color_scheme' => 'blue' }
    when 'upcoming_deadlines'
      { 'days_ahead' => 7, 'show_overdue' => true, 'group_by_type' => true }
    when 'recent_notes'
      { 'limit' => 5, 'show_previews' => true, 'sort_by' => 'updated_at' }
    when 'assignment_progress'
      { 'show_percentages' => true, 'chart_type' => 'donut', 'include_completed' => false }
    when 'communication_overview'
      { 'show_unread_count' => true, 'include_discussions' => true, 'limit' => 8 }
    when 'calendar_preview'
      { 'days_ahead' => 3, 'show_time' => true, 'compact_view' => false }
    when 'grade_overview'
      { 'show_trends' => true, 'chart_type' => 'line', 'period' => 'semester' }
    when 'discussion_feed'
      { 'limit' => 6, 'show_replies' => false, 'sort_by' => 'activity' }
    when 'learning_insights'
      { 'show_recommendations' => true, 'limit' => 5, 'categories' => 'all' }
    when 'weather'
      { 'show_forecast' => true, 'units' => 'metric', 'location' => 'auto' }
    when 'quick_actions'
      { 'show_icons' => true, 'layout' => 'grid', 'actions' => ['new_note', 'new_assignment', 'calendar', 'messages'] }
    else
      {}
    end
  end
end