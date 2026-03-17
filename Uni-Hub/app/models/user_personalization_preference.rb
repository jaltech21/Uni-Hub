# app/models/user_personalization_preference.rb
class UserPersonalizationPreference < ApplicationRecord
  belongs_to :user
  
  # Available themes
  THEMES = {
    'light' => 'Light Mode',
    'dark' => 'Dark Mode',
    'auto' => 'Auto (System)',
    'blue' => 'Blue Theme',
    'green' => 'Green Theme',
    'purple' => 'Purple Theme'
  }.freeze
  
  # Layout styles
  LAYOUT_STYLES = {
    'standard' => 'Standard Layout',
    'compact' => 'Compact Layout',
    'spacious' => 'Spacious Layout',
    'minimal' => 'Minimal Layout'
  }.freeze
  
  # Validation
  validates :theme, inclusion: { in: THEMES.keys }
  validates :layout_style, inclusion: { in: LAYOUT_STYLES.keys }
  validates :user_id, uniqueness: true
  
  # Callbacks
  before_validation :set_defaults
  after_initialize :set_default_preferences
  before_save :update_timestamp
  
  # Class methods
  def self.available_themes
    THEMES
  end
  
  def self.available_layout_styles
    LAYOUT_STYLES
  end
  
  def self.for_user(user)
    find_or_create_by(user: user)
  end
  
  # Instance methods
  def dashboard_layout_with_defaults
    default_layout = {
      'grid_columns' => 12,
      'grid_gap' => 16,
      'widget_margin' => 8,
      'auto_arrange' => false,
      'show_grid_lines' => false
    }
    default_layout.merge(dashboard_layout || {})
  end
  
  def ui_preferences_with_defaults
    default_preferences = {
      'animations_enabled' => true,
      'sound_effects' => false,
      'high_contrast' => false,
      'reduced_motion' => false,
      'font_size' => 'medium',
      'sidebar_position' => 'left',
      'quick_actions_visible' => true,
      'breadcrumbs_enabled' => true,
      'tooltips_enabled' => true,
      'keyboard_shortcuts' => true
    }
    default_preferences.merge(ui_preferences || {})
  end
  
  def color_scheme_with_defaults
    default_colors = case theme
    when 'dark'
      {
        'primary' => '#3B82F6',
        'secondary' => '#64748B',
        'background' => '#0F172A',
        'surface' => '#1E293B',
        'text_primary' => '#F8FAFC',
        'text_secondary' => '#CBD5E1'
      }
    when 'blue'
      {
        'primary' => '#1E40AF',
        'secondary' => '#3B82F6',
        'background' => '#F8FAFC',
        'surface' => '#FFFFFF',
        'text_primary' => '#1E293B',
        'text_secondary' => '#64748B'
      }
    when 'green'
      {
        'primary' => '#059669',
        'secondary' => '#10B981',
        'background' => '#F0FDF4',
        'surface' => '#FFFFFF',
        'text_primary' => '#1E293B',
        'text_secondary' => '#64748B'
      }
    when 'purple'
      {
        'primary' => '#7C3AED',
        'secondary' => '#A855F7',
        'background' => '#FAF5FF',
        'surface' => '#FFFFFF',
        'text_primary' => '#1E293B',
        'text_secondary' => '#64748B'
      }
    else # light
      {
        'primary' => '#3B82F6',
        'secondary' => '#64748B',
        'background' => '#F8FAFC',
        'surface' => '#FFFFFF',
        'text_primary' => '#1E293B',
        'text_secondary' => '#64748B'
      }
    end
    
    default_colors.merge(color_scheme || {})
  end
  
  def accessibility_settings_with_defaults
    default_accessibility = {
      'screen_reader_support' => false,
      'high_contrast_mode' => false,
      'large_text' => false,
      'reduced_motion' => false,
      'keyboard_navigation' => true,
      'focus_indicators' => true,
      'alt_text_enabled' => true,
      'color_blind_support' => false
    }
    default_accessibility.merge(accessibility_settings || {})
  end
  
  def apply_theme_to_css
    colors = color_scheme_with_defaults
    ui_prefs = ui_preferences_with_defaults
    
    css_variables = {
      '--primary-color' => colors['primary'],
      '--secondary-color' => colors['secondary'],
      '--background-color' => colors['background'],
      '--surface-color' => colors['surface'],
      '--text-primary' => colors['text_primary'],
      '--text-secondary' => colors['text_secondary'],
      '--font-size-base' => font_size_to_css(ui_prefs['font_size']),
      '--animation-duration' => ui_prefs['animations_enabled'] ? '0.3s' : '0s',
      '--border-radius' => layout_style == 'minimal' ? '4px' : '8px',
      '--shadow-intensity' => layout_style == 'minimal' ? '0.05' : '0.1'
    }
    
    css_variables
  end
  
  def is_dark_theme?
    theme == 'dark' || (theme == 'auto' && system_prefers_dark?)
  end
  
  def effective_theme
    return theme unless theme == 'auto'
    system_prefers_dark? ? 'dark' : 'light'
  end
  
  def needs_high_contrast?
    accessibility_settings_with_defaults['high_contrast_mode']
  end
  
  def reduced_motion_enabled?
    accessibility_settings_with_defaults['reduced_motion'] || 
    ui_preferences_with_defaults['reduced_motion']
  end
  
  private
  
  def set_defaults
    self.theme ||= 'light'
    self.layout_style ||= 'standard'
    self.sidebar_collapsed = false if sidebar_collapsed.nil?
  end
  
  def set_default_preferences
    self.dashboard_layout ||= {}
    self.ui_preferences ||= {}
    self.color_scheme ||= {}
    self.accessibility_settings ||= {}
  end
  
  def update_timestamp
    self.last_updated_at = Time.current
  end
  
  def font_size_to_css(size)
    case size
    when 'small' then '14px'
    when 'large' then '18px'
    when 'extra-large' then '20px'
    else '16px' # medium
    end
  end
  
  def system_prefers_dark?
    # This would typically be determined by JavaScript and stored
    # For now, we'll default to false
    false
  end
end