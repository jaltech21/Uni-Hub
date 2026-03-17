class DepartmentSetting < ApplicationRecord
  belongs_to :department
  
  # Validations
  validates :primary_color, format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/, message: 'must be a valid hex color' }, allow_blank: true
  validates :secondary_color, format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/, message: 'must be a valid hex color' }, allow_blank: true
  validates :default_assignment_visibility, inclusion: { in: %w[department shared private] }
  validates :default_note_visibility, inclusion: { in: %w[department shared private] }
  validates :default_quiz_visibility, inclusion: { in: %w[department shared private] }
  
  # Callbacks
  after_initialize :set_defaults, if: :new_record?
  
  # Class constants
  VISIBILITY_OPTIONS = %w[department shared private].freeze
  
  # Class methods
  def self.visibility_options
    [
      ['Department Only', 'department'],
      ['Shared Across Departments', 'shared'],
      ['Private', 'private']
    ]
  end
  
  # Instance methods
  def update_template(template_type, template_data)
    # Normalize the template type to handle both symbols and strings
    type = template_type.to_s.gsub('_templates', '')
    
    case type
    when 'assignment', 'assignment_templates'
      templates = assignment_templates || []
      templates << template_data
      update(assignment_templates: templates)
    when 'quiz', 'quiz_templates'
      templates = quiz_templates || []
      templates << template_data
      update(quiz_templates: templates)
    else
      false
    end
  end
  
  def remove_template(template_type, template_id)
    # Normalize the template type
    type = template_type.to_s.gsub('_templates', '')
    
    case type
    when 'assignment', 'assignment_templates'
      templates = assignment_templates || []
      templates.reject! { |t| t['id'] == template_id }
      update(assignment_templates: templates)
    when 'quiz', 'quiz_templates'
      templates = quiz_templates || []
      templates.reject! { |t| t['id'] == template_id }
      update(quiz_templates: templates)
    else
      false
    end
  end
  
  def get_template(template_type, template_id)
    # Normalize the template type
    type = template_type.to_s.gsub('_templates', '')
    
    templates = case type
                when 'assignment', 'assignment_templates' then assignment_templates || []
                when 'quiz', 'quiz_templates' then quiz_templates || []
                else []
                end
    
    templates.find { |t| t['id'] == template_id }
  end
  
  def has_branding?
    logo_url.present? || banner_url.present? || 
      (primary_color.present? && primary_color != '#3B82F6') ||
      (secondary_color.present? && secondary_color != '#10B981')
  end
  
  def has_welcome_message?
    welcome_message.present?
  end
  
  def custom_field(key)
    (custom_fields || {})[key.to_s]
  end
  
  def set_custom_field(key, value)
    fields = custom_fields || {}
    fields[key.to_s] = value
    update(custom_fields: fields)
  end
  
  private
  
  def set_defaults
    self.primary_color ||= '#3B82F6'
    self.secondary_color ||= '#10B981'
    self.default_assignment_visibility ||= 'department'
    self.default_note_visibility ||= 'private'
    self.default_quiz_visibility ||= 'department'
    self.enable_announcements = true if enable_announcements.nil?
    self.enable_content_sharing = true if enable_content_sharing.nil?
    self.enable_peer_review = false if enable_peer_review.nil?
    self.enable_gamification = false if enable_gamification.nil?
    self.notify_new_members = true if notify_new_members.nil?
    self.notify_new_content = true if notify_new_content.nil?
    self.notify_submissions = true if notify_submissions.nil?
  end
end
