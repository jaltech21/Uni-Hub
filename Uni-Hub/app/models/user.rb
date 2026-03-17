class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  after_initialize :set_default_role, if: :new_record?

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  #enum role: { student: 'student', teacher: 'teacher', admin: 'admin' }

  # Department associations
  belongs_to :department, optional: true  # For students (single department)
  has_many :user_departments, dependent: :destroy  # For tutors (multiple departments)
  has_many :teaching_departments, through: :user_departments, source: :department

  has_many :assignments
  has_many :submissions
  has_many :notes
  has_many :folders, dependent: :destroy
  has_many :schedules
  has_many :attendance_lists
  has_many :attendance_records
  has_many :quizzes, dependent: :destroy
  has_many :quiz_attempts, dependent: :destroy
  has_many :shared_notes, class_name: 'NoteShare', foreign_key: 'shared_with_id', dependent: :destroy
  has_many :accessible_notes, through: :shared_notes, source: :note
  has_many :notifications, dependent: :destroy
  has_many :ai_usage_logs, dependent: :destroy
  has_many :learning_insights, dependent: :destroy
  
  # Communication associations
  has_many :sent_messages, class_name: 'ChatMessage', foreign_key: 'sender_id', dependent: :destroy
  has_many :received_messages, class_name: 'ChatMessage', foreign_key: 'recipient_id', dependent: :destroy
  has_many :discussions, dependent: :destroy
  has_many :discussion_posts, dependent: :destroy
  
  # Personalization associations
  has_many :user_dashboard_widgets, dependent: :destroy
  has_one :user_personalization_preference, dependent: :destroy
  
  # Compliance associations
  has_many :compliance_assessments, foreign_key: 'assessor_id', dependent: :destroy
  has_many :generated_compliance_reports, class_name: 'ComplianceReport', foreign_key: 'generated_by_id', dependent: :destroy
  has_many :audit_trails, foreign_key: 'user_id', dependent: :destroy
  
  # Schedule associations
  has_many :created_schedules, class_name: 'Schedule', foreign_key: 'user_id'
  has_many :instructed_schedules, class_name: 'Schedule', foreign_key: 'instructor_id'
  has_many :schedule_participants, dependent: :destroy
  has_many :enrolled_schedules, through: :schedule_participants, source: :schedule
  
  # Teaching assignments (for teachers)
  has_many :taught_schedules, foreign_key: :instructor_id, class_name: 'Schedule'
  
  # Enrolled courses (for students)
  has_many :enrollments, dependent: :destroy
  has_many :active_enrollments, -> { where(status: 'active') }, 
           class_name: 'Enrollment'
  has_many :active_schedules, through: :active_enrollments, source: :schedule
  
  # Blacklist associations
  belongs_to :blacklisted_by_user, class_name: 'User', foreign_key: 'blacklisted_by_id', optional: true
  belongs_to :unblacklisted_by_user, class_name: 'User', foreign_key: 'unblacklisted_by_id', optional: true
  
  # Assignments
  has_many :created_assignments, foreign_key: :user_id, 
           class_name: 'Assignment', dependent: :destroy

  # Analytics
  has_many :analytics_dashboards, dependent: :destroy
  has_many :analytics_reports, dependent: :destroy

  validates :role, presence: true, inclusion: { in: %w[student teacher tutor admin super_admin compliance_manager compliance_assessor department_head] }
  
  # Username validations
  validates :username, 
    presence: true,
    uniqueness: { case_sensitive: false },
    length: { minimum: 3, maximum: 20 },
    format: { 
      with: /\A[a-zA-Z0-9_]+\z/, 
      message: "can only contain letters, numbers, and underscores" 
    }
  
  # Normalize username before validation
  before_validation :normalize_username
  
  # Blacklist scopes
  scope :blacklisted, -> { where(blacklisted: true) }
  scope :active_users, -> { where(blacklisted: [false, nil]) }
  scope :by_role, ->(role) { where(role: role) }
  scope :search_by_name_or_email, ->(query) { 
    where('first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?', "%#{query}%", "%#{query}%", "%#{query}%") 
  }
  
  # Role checking methods
  ROLES = %w[student tutor admin].freeze

  # Ransack requires explicit allowlisting of searchable attributes for ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    %w[id email role created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[assignments submissions notes folders schedules attendance_lists attendance_records created_schedules instructed_schedules schedule_participants enrolled_schedules quizzes quiz_attempts shared_notes accessible_notes notifications].freeze
  end
  
  # Get unread notification count
  def unread_notifications_count
    notifications.unread.count
  end
  
  # Get recent notifications
  def recent_notifications(limit = 10)
    notifications.recent.limit(limit)
  end
  
  # Messaging methods
  def unread_messages_count
    received_messages.unread.count
  end
  
  def conversation_with(other_user)
    ChatMessage.between_users(self, other_user)
  end
  
  def has_conversation_with?(other_user)
    ChatMessage.between_users(self, other_user).exists?
  end
  
  def send_message_to(recipient, content, message_type: 'text')
    sent_messages.create!(
      recipient: recipient,
      content: content,
      message_type: message_type
    )
  end

  def student?
    self.role == 'student'
  end

  def teacher?
    self.role == 'teacher' || self.role == 'tutor'
  end
  
  def tutor?
    self.role == 'tutor'
  end
  
  def admin?
    self.role == 'admin'
  end
  
  # Teaching capacity methods
  def can_teach_more_courses?
    return false unless teacher?
    taught_schedules.count < (max_courses || 3)
  end
  
  def available_course_slots
    return 0 unless teacher?
    (max_courses || 3) - taught_schedules.count
  end
  
  # Get assignments visible to this user
  def visible_assignments
    if teacher?
      created_assignments.includes(:schedule, :submissions)
    else
      Assignment.visible_to_student(self).includes(:schedule, :user)
    end
  end
  
  # Check if enrolled in a specific course
  def enrolled_in?(schedule)
    active_enrollments.exists?(schedule_id: schedule.id)
  end
  
  # Get primary enrollment (students can only be in one course)
  def primary_enrollment
    active_enrollments.first
  end
  
  def primary_course
    primary_enrollment&.schedule
  end
  
  def tutor?
    self.role == 'tutor'
  end
  
  def admin?
    self.role == 'admin'
  end
  
  def super_admin?
    self.role == 'super_admin'
  end
  
  def compliance_manager?
    self.role == 'compliance_manager'
  end
  
  def compliance_assessor?
    self.role == 'compliance_assessor'
  end
  
  def department_head?
    self.role == 'department_head'
  end

  def has_role?(*roles)
    roles.map(&:to_s).include?(role)
  end
  
  # Get all departments this user has access to
  def all_departments
    if student?
      # Students have only their single department
      department ? [department] : []
    elsif tutor? || teacher?
      # Tutors use the join table for multiple departments
      teaching_departments.to_a
    elsif admin? || super_admin?
      # Admins see all departments
      Department.all.to_a
    else
      []
    end
  end
  
  # Check if user has access to a specific department
  def can_access_department?(dept)
    return true if admin? || super_admin?
    all_departments.include?(dept)
  end

  def full_name
    # If first_name and last_name exist, use them, otherwise use email
    if respond_to?(:first_name) && respond_to?(:last_name) && first_name.present? && last_name.present?
      "#{first_name} #{last_name}"
    else
      email.split('@').first.titleize
    end
  end
  
  # Alias for convenience
  alias_method :name, :full_name
  
  # Personalization methods
  def personalization_preferences
    user_personalization_preference || create_user_personalization_preference!
  end
  
  def dashboard_widgets
    user_dashboard_widgets.enabled.ordered
  end
  
  def setup_default_dashboard!
    return if user_dashboard_widgets.exists?
    
    default_widgets = UserDashboardWidget.default_widgets_for_user(self)
    default_widgets.each do |widget_attrs|
      user_dashboard_widgets.create!(widget_attrs)
    end
  end
  
  def theme_preference
    personalization_preferences.effective_theme
  end
  
  def ui_preferences
    personalization_preferences.ui_preferences_with_defaults
  end
  
  def dashboard_layout
    personalization_preferences.dashboard_layout_with_defaults
  end
  
  # Push notification methods
  def has_push_subscription?
    push_subscription.present?
  end
  
  def update_push_subscription(subscription_data)
    update!(push_subscription: subscription_data)
  end
  
  def clear_push_subscription
    update!(push_subscription: nil)
  end
  
  def notification_preferences
    super || default_notification_preferences
  end
  
  def wants_notification?(type)
    notification_preferences.dig('enabled', type.to_s) != false
  end
  
  def enable_notification(type)
    prefs = notification_preferences
    prefs['enabled'] ||= {}
    prefs['enabled'][type.to_s] = true
    update!(notification_preferences: prefs)
  end
  
  def disable_notification(type)
    prefs = notification_preferences
    prefs['enabled'] ||= {}
    prefs['enabled'][type.to_s] = false
    update!(notification_preferences: prefs)
  end
  
  # Blacklist methods
  def blacklisted?
    blacklisted == true
  end
  
  def can_login?
    !blacklisted?
  end
  
  def blacklist!(admin_user, reason)
    update!(
      blacklisted: true,
      blacklisted_at: Time.current,
      blacklisted_by_id: admin_user.id,
      blacklist_reason: reason
    )
  end
  
  def unblacklist!(admin_user)
    update!(
      blacklisted: false,
      unblacklisted_at: Time.current,
      unblacklisted_by_id: admin_user.id
    )
  end
  
  # Override Devise method to check blacklist status
  def active_for_authentication?
    super && !blacklisted?
  end
  
  # Custom message when user is blacklisted
  def inactive_message
    blacklisted? ? :blacklisted : super
  end
  
  private

  def set_default_role
    self.role ||= 'student'
  end
  
  def normalize_username
    self.username = username.to_s.downcase.strip if username.present?
  end
  
  def default_notification_preferences
    {
      'enabled' => {
        'messages' => true,
        'announcements' => true,
        'assignments' => true,
        'reminders' => true,
        'discussions' => true
      },
      'sound' => true,
      'vibrate' => true
    }
  end
end
