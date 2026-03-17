class Admin::DashboardController < ApplicationController
  layout 'admin'
  before_action :authenticate_admin!

  def index
    @courses_count = Course.count
    @active_courses_count = Course.active.count
    @schedules_count = Schedule.count
    @enrollments_count = Enrollment.active.count
    @users_count = User.count
    @students_count = User.where(role: 'student').count
    @teachers_count = User.where(role: 'teacher').count
    @departments_count = Department.count
    @active_departments_count = Department.where(active: true).count
    @blacklisted_users_count = User.blacklisted.count
    
    @recent_courses = Course.order(created_at: :desc).limit(5)
    @recent_schedules = Schedule.order(created_at: :desc).limit(5)
    @recent_audit_logs = AdminAuditLog.includes(:admin).recent.limit(10)
  end

  private

  def authenticate_admin!
    unless user_signed_in? && current_user.admin?
      redirect_to new_admin_session_path, alert: 'Please sign in with an admin account.'
    end
  end
end
