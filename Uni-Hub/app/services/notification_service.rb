class NotificationService
  def self.create_notification(user:, title:, message:, notification_type:, related_object: nil, action_url: nil)
    return if user.nil?

    Notification.create!(
      user: user,
      title: title,
      message: message,
      notification_type: notification_type,
      notifiable: related_object,
      action_url: action_url
    )
  end

  # Course lifecycle notifications
  def self.notify_course_created(course, department = nil)
    department = course.department if department.nil?
    return if department.nil?

    department_users(department).find_each do |user|
      NotificationService.create_notification(
        user: user,
        title: "New Course Added",
message: "A new course #{course.full_name} has been added to #{department.name}.",
        notification_type: "course_created",
        related_object: course
      )
    end
  end

  def self.notify_course_updated(course)
    users = department_users(course.department)
    users.find_each do |user|
      NotificationService.create_notification(
        user: user,
        title: "Course Updated",
        message: "Course #{course.full_name} has been updated.",
        notification_type: "course_updated",
        related_object: course
      )
    end
  end

  def self.notify_course_deactivated(course)
    courses_users(course).find_each do |user|
      next if user.nil?

      NotificationService.create_notification(
        user: user,
        title: "Course Deactivated",
        message: "Course #{course.full_name} has been deactivated.",
        notification_type: "course_deactivated",
        related_object: course
      )
    end
  end

  # Schedule lifecycle notifications
  def self.notify_schedule_approved(schedule)
    instructor = schedule.instructor || schedule.user
    users = ([instructor] + schedule.active_students.to_a).compact.uniq
    users.each do |user|
      NotificationService.create_notification(
        user: user,
        title: "Schedule Approved",
        message: "Your class #{schedule.title} has been approved.",
        notification_type: "schedule_approved",
        related_object: schedule
      )
    end
  end

  def self.notify_schedule_cancelled(schedule, reason = nil)
    text = reason.present? ? "has been cancelled. Reason: #{reason}" : "has been cancelled."
    users = ([schedule.instructor, schedule.user] + schedule.active_students.to_a).compact.uniq
    users.each do |user|
      NotificationService.create_notification(
        user: user,
        title: "Schedule Cancelled",
        message: "Class #{schedule.title} #{text}",
        notification_type: "schedule_cancelled",
        related_object: schedule
      )
    end
  end

  # Announcement published notification
  def self.notify_announcement_published(announcement)
    department = announcement.department
    return if department.nil?

    department_users(department).find_each do |user|
      NotificationService.create_notification(
        user: user,
        title: "New Announcement",
        message: announcement.title,
        notification_type: "announcement_published",
        related_object: announcement
      )
    end
  end

  # Password reset by admin
  def self.notify_password_reset(user, temp_password)
    return if user.nil?

    NotificationService.create_notification(
      user: user,
      title: "Password Reset",
      message: "An administrator reset your password. Your temporary password is: #{temp_password}",
      notification_type: "password_reset",
      related_object: user
    )
  end

  def self.department_users(department)
    return User.none if department.nil?

    User.where(id: department.users.ids + User.where(department_id: department.id).ids).uniq
  end

  private

  def self.courses_users(course)
    schedule_ids = course.course_schedules.pluck(:id)
    return User.none if schedule_ids.empty?

    student_ids = ScheduleParticipant.where(schedule_id: schedule_ids, role: "student").pluck(:user_id)
    return User.none if student_ids.empty?

    User.where(id: student_ids)
  end
  private_class_method :courses_users
end