class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true
  
  validates :notification_type, presence: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :message, length: { maximum: 1000 }
  
  # Notification types
  TYPES = %w[
    assignment_created
    assignment_due_soon
    assignment_graded
    submission_received
    schedule_created
    schedule_updated
    schedule_reminder
    note_shared
    quiz_shared
    general
  ].freeze
  
  validates :notification_type, inclusion: { in: TYPES }
  
  scope :unread, -> { where(read: false) }
  scope :read_notifications, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  
  # Mark as read
  def mark_as_read!
    update(read: true)
  end
  
  # Mark as unread
  def mark_as_unread!
    update(read: false)
  end
  
  # Get icon based on type
  def icon
    case notification_type
    when 'assignment_created', 'assignment_due_soon'
      'clipboard'
    when 'assignment_graded', 'submission_received'
      'check-circle'
    when 'schedule_created', 'schedule_updated', 'schedule_reminder'
      'calendar'
    when 'note_shared', 'quiz_shared'
      'share'
    else
      'bell'
    end
  end
  
  # Get color based on type
  def color
    case notification_type
    when 'assignment_created', 'submission_received'
      'blue'
    when 'assignment_due_soon'
      'orange'
    when 'assignment_graded'
      'green'
    when 'schedule_created', 'schedule_updated'
      'purple'
    when 'schedule_reminder'
      'yellow'
    when 'note_shared', 'quiz_shared'
      'indigo'
    else
      'gray'
    end
  end
  
  # Time ago in words helper
  def time_ago
    time_diff = Time.current - created_at
    
    case time_diff
    when 0..59
      'just now'
    when 60..3599
      "#{(time_diff / 60).to_i}m ago"
    when 3600..86399
      "#{(time_diff / 3600).to_i}h ago"
    when 86400..604799
      "#{(time_diff / 86400).to_i}d ago"
    else
      created_at.strftime('%b %d')
    end
  end
  
  # Create notification helper methods
  class << self
    def notify_assignment_created(user, assignment)
      create!(
        user: user,
        notification_type: 'assignment_created',
        title: 'New Assignment',
        message: "#{assignment.title} has been posted",
        notifiable: assignment,
        action_url: Rails.application.routes.url_helpers.assignment_path(assignment)
      )
    end
    
    def notify_assignment_due_soon(user, assignment)
      create!(
        user: user,
        notification_type: 'assignment_due_soon',
        title: 'Assignment Due Soon',
        message: "#{assignment.title} is due #{assignment.due_date.strftime('%b %d at %I:%M %p')}",
        notifiable: assignment,
        action_url: Rails.application.routes.url_helpers.assignment_path(assignment)
      )
    end
    
    def notify_assignment_graded(user, submission)
      create!(
        user: user,
        notification_type: 'assignment_graded',
        title: 'Assignment Graded',
        message: "Your submission for #{submission.assignment.title} has been graded",
        notifiable: submission,
        action_url: Rails.application.routes.url_helpers.assignment_submission_path(submission.assignment, submission)
      )
    end
    
    def notify_submission_received(user, submission)
      create!(
        user: user,
        notification_type: 'submission_received',
        title: 'New Submission',
        message: "#{submission.user.full_name} submitted #{submission.assignment.title}",
        notifiable: submission,
        action_url: Rails.application.routes.url_helpers.assignment_submission_path(submission.assignment, submission)
      )
    end
    
    def notify_schedule_created(user, schedule)
      create!(
        user: user,
        notification_type: 'schedule_created',
        title: 'New Class Added',
        message: "#{schedule.course_name} has been added to your schedule",
        notifiable: schedule,
        action_url: Rails.application.routes.url_helpers.schedules_path
      )
    end
    
    def notify_schedule_updated(user, schedule)
      create!(
        user: user,
        notification_type: 'schedule_updated',
        title: 'Schedule Updated',
        message: "#{schedule.course_name} schedule has been updated",
        notifiable: schedule,
        action_url: Rails.application.routes.url_helpers.schedules_path
      )
    end
    
    def notify_note_shared(user, note, shared_by)
      create!(
        user: user,
        notification_type: 'note_shared',
        title: 'Note Shared With You',
        message: "#{shared_by.full_name} shared '#{note.title}' with you",
        notifiable: note,
        action_url: Rails.application.routes.url_helpers.note_path(note)
      )
    end
  end
end
