class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :features, :pricing, :about]
  layout 'dashboard', only: [:dashboard]
  
  def home
  end

  def features
  end

  def pricing
  end

  def about
  end

  def dashboard
    if current_user.teacher?
      # Teacher Dashboard Data - only assignments from taught courses
      @total_assignments = current_user.created_assignments.count
      @pending_submissions = Submission.joins(:assignment)
                                      .where(assignments: { user_id: current_user.id })
                                      .where(status: 'submitted')
                                      .count
      @graded_submissions = Submission.joins(:assignment)
                                     .where(assignments: { user_id: current_user.id })
                                     .where(status: 'graded')
                                     .count
      @recent_assignments = current_user.created_assignments
                                        .includes(:schedule)
                                        .order(created_at: :desc)
                                        .limit(5)
      
      # Schedule Data - courses being taught
      @taught_schedules = current_user.taught_schedules
      @total_schedules = @taught_schedules.count
      @total_enrolled_students = @taught_schedules.sum { |s| s.active_enrollments.count }
      @unique_courses = @taught_schedules.pluck(:course).uniq.count
      @upcoming_schedules = @taught_schedules.where(recurring: true)
                                            .order(:day_of_week, :start_time)
                                            .limit(5)
    else
      # Student Dashboard Data - only assignments from enrolled course
      visible_assignments = current_user.visible_assignments
      @total_assignments = visible_assignments.count
      @pending_assignments = visible_assignments.where('due_date > ?', Time.current)
                                               .where.not(id: Submission.where(user_id: current_user.id).pluck(:assignment_id))
                                               .count
      @submitted_assignments = Submission.where(user_id: current_user.id, status: ['submitted', 'graded']).count
      @graded_submissions = Submission.where(user_id: current_user.id, status: 'graded').count
      @upcoming_assignments = visible_assignments.where('due_date > ?', Time.current)
                                                 .includes(:schedule)
                                                 .order(:due_date)
                                                 .limit(5)
      @recent_grades = Submission.where(user_id: current_user.id, status: 'graded')
                                .includes(assignment: :schedule)
                                .order(graded_at: :desc)
                                .limit(5)
      
      # Enrollment Data
      @enrollments_count = current_user.active_enrollments.count
      @primary_enrollment = current_user.primary_enrollment
      @primary_course = current_user.primary_course
      @today_schedules = @primary_course && @primary_course.day_of_week == Time.current.wday ? [@primary_course] : []
    end
  end
end
