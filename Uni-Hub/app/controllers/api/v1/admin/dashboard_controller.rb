module Api
  module V1
    module Admin
      class DashboardController < BaseController
        def index
          render_success({
            users_count: User.count,
            students_count: User.where(role: "student").count,
            teachers_count: User.where(role: %w[teacher tutor]).count,
            admins_count: User.where(role: "admin").count,
            courses_count: Course.count,
            active_courses_count: Course.active.count,
            schedules_count: Schedule.count,
            enrollments_count: Enrollment.active.count,
            departments_count: Department.count,
            active_departments_count: Department.where(active: true).count,
            blacklisted_users_count: User.blacklisted.count
          })
        end
      end
    end
  end
end