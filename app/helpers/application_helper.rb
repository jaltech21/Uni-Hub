module ApplicationHelper
  def theme_body_class
    return 'bg-gray-50' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    classes = []
    
    # Add theme class
    case pref.theme
    when 'dark'
      classes << 'theme-dark bg-gray-900 text-white'
    when 'blue'
      classes << 'theme-blue bg-blue-50'
    when 'green'
      classes << 'theme-green bg-green-50'
    when 'purple'
      classes << 'theme-purple bg-purple-50'
    else
      classes << 'theme-light bg-gray-50'
    end
    
    # Add layout class
    classes << "layout-#{pref.layout_style}"
    
    classes.join(' ')
  end
  
  def navbar_theme_class
    return 'bg-white' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'bg-gray-800 text-white'
    when 'blue'
      'bg-blue-600 text-white'
    when 'green'
      'bg-green-600 text-white'
    when 'purple'
      'bg-purple-600 text-white'
    else
      'bg-white'
    end
  end
  
  def text_theme_class
    return 'text-gray-900' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    pref.theme == 'dark' ? 'text-white' : 'text-gray-900'
  end
  
  def card_theme_class
    return 'bg-white' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'bg-gray-800 text-white'
    when 'blue'
      'bg-white'
    when 'green'
      'bg-white'
    when 'purple'
      'bg-white'
    else
      'bg-white'
    end
  end
  
  def sidebar_theme_class
    return 'bg-blue-300' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'bg-gray-800 text-gray-100'
    when 'blue'
      'bg-blue-700 text-white'
    when 'green'
      'bg-green-700 text-white'
    when 'purple'
      'bg-purple-700 text-white'
    else
      'bg-blue-300'
    end
  end
  
  def content_wrapper_theme_class
    return 'bg-gray-100' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'bg-gray-900 text-gray-100'
    when 'blue'
      'bg-blue-50'
    when 'green'
      'bg-green-50'
    when 'purple'
      'bg-purple-50'
    else
      'bg-gray-100'
    end
  end
  
  def border_theme_class
    return 'border-gray-200' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    pref.theme == 'dark' ? 'border-gray-700' : 'border-gray-200'
  end
  
  def link_text_theme_class
    return 'text-gray-700' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'text-gray-100'
    when 'blue'
      'text-blue-900'
    when 'green'
      'text-green-900'
    when 'purple'
      'text-purple-900'
    else
      'text-gray-700'
    end
  end
  
  def icon_theme_class
    return 'text-blue-600' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'text-gray-300'
    when 'blue'
      'text-blue-600'
    when 'green'
      'text-green-600'
    when 'purple'
      'text-purple-600'
    else
      'text-blue-600'
    end
  end
  
  def hover_theme_class
    return 'hover:text-blue-600 hover:bg-blue-50' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    
    case pref.theme
    when 'dark'
      'hover:text-gray-100 hover:bg-gray-700'
    when 'blue'
      'hover:text-blue-700 hover:bg-blue-100'
    when 'green'
      'hover:text-green-700 hover:bg-green-100'
    when 'purple'
      'hover:text-purple-700 hover:bg-purple-100'
    else
      'hover:text-blue-600 hover:bg-blue-50'
    end
  end
  
  def heading_theme_class
    return 'text-gray-900' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    pref.theme == 'dark' ? 'text-white' : 'text-gray-900'
  end
  
  def subtext_theme_class
    return 'text-gray-600' unless user_signed_in? && current_user.user_personalization_preference.present?
    
    pref = current_user.user_personalization_preference
    pref.theme == 'dark' ? 'text-gray-400' : 'text-gray-600'
  end
  
  def markdown(text)
    return '' if text.blank?
    
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,  # Allow HTML tags for underline
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener noreferrer' }
    )
    
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      space_after_headers: true,
      fenced_code_blocks: true,
      underline: false,  # Disable to avoid conflict with bold
      highlight: true,
      strikethrough: true,
      tables: true,
      no_intra_emphasis: true
    )
    
    markdown.render(text).html_safe
  end
  
  def insight_type_icon(insight_type)
    icons = {
      'at_risk_prediction' => 'exclamation-triangle',
      'performance_decline' => 'chart-line-down',
      'engagement_drop' => 'user-slash',
      'learning_style_mismatch' => 'puzzle-piece',
      'content_difficulty' => 'book-open',
      'participation_low' => 'hand-paper',
      'assignment_struggles' => 'tasks',
      'attendance_issues' => 'calendar-times',
      'peer_comparison' => 'users',
      'recommendation' => 'lightbulb'
    }
    
    icons[insight_type] || 'info-circle'
  end
  
  def status_color(status)
    colors = {
      'active' => 'warning',
      'implemented' => 'success', 
      'dismissed' => 'secondary',
      'archived' => 'dark'
    }
    colors[status] || 'secondary'
  end
end
