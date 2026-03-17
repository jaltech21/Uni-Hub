module Departments
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :set_department
    before_action :authorize_dashboard_access

    def show
      @statistics = DepartmentStatisticsService.new(@department).statistics
      @recent_assignments = policy_scope(Assignment)
                             .where(department: @department)
                             .order(created_at: :desc)
                             .limit(5)
      @recent_quizzes = policy_scope(Quiz)
                         .where(department: @department)
                         .order(created_at: :desc)
                         .limit(5)
      @recent_notes = policy_scope(Note)
                       .where(department: @department)
                       .order(created_at: :desc)
                       .limit(5)
      @activity_timeline = build_activity_timeline
    end

    private

    def set_department
      @department = Department.find(params[:department_id])
    end

    def authorize_dashboard_access
      unless is_admin? || can_access_department?(@department)
        redirect_to root_path, alert: 'You are not authorized to view this dashboard.'
      end
    end

    def is_admin?
      current_user.admin? || current_user.super_admin?
    end

    def can_access_department?(department)
      return true if current_user.department_id == department.id
      return true if current_user.teaching_departments.include?(department)
      false
    end

    def build_activity_timeline
      # Get recent activity from various models
      activities = []

      # Recent assignments
      Assignment.where(department: @department)
                .where('created_at >= ?', 1.week.ago)
                .each do |assignment|
        activities << {
          type: 'assignment',
          icon: '📚',
          title: assignment.title,
          description: "New assignment created",
          timestamp: assignment.created_at,
          user: assignment.user&.name || 'System'
        }
      end

      # Recent quizzes
      Quiz.where(department: @department)
          .where('created_at >= ?', 1.week.ago)
          .each do |quiz|
        activities << {
          type: 'quiz',
          icon: '📝',
          title: quiz.title,
          description: quiz.status == 'published' ? "Quiz published" : "Quiz created",
          timestamp: quiz.created_at,
          user: quiz.user&.name || 'System'
        }
      end

      # Recent notes
      Note.where(department: @department)
          .where('created_at >= ?', 1.week.ago)
          .each do |note|
        activities << {
          type: 'note',
          icon: '📓',
          title: note.title,
          description: "New note added",
          timestamp: note.created_at,
          user: note.user&.name || 'System'
        }
      end

      # Sort by timestamp descending and limit to 10
      activities.sort_by { |a| a[:timestamp] }.reverse.take(10)
    end
  end
end
