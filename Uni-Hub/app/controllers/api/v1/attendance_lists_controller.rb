module Api
  module V1
    class AttendanceListsController < BaseController
      before_action :require_teacher!, only: [:create]

      def index
        if current_user.teacher?
          lists = current_user.attendance_lists.order(date: :desc, created_at: :desc)
        else
          department_schedule_ids = current_user.enrolled_schedules.joins(:department)
                                                    .distinct.pluck(:id)
          teacher_ids = Schedule.where(id: department_schedule_ids).distinct.pluck(:user_id)
          lists = AttendanceList.where(user_id: teacher_ids)
                                .where("date >= ?", Date.current)
                                .order(created_at: :desc)
        end
        render_success(lists.map { |l| serialize_list(l) })
      end

      def create
        list = current_user.attendance_lists.build(attendance_list_params)
        if list.save
          render_success(serialize_list(list), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: list.errors.messages
          )
        end
      end

      private

      def require_teacher!
        render_forbidden unless current_user.teacher?
      end

      def attendance_list_params
        params.expect(attendance_list: {}).permit(:title, :description, :date)
      end

      def serialize_list(attendance_list)
        {
          id: attendance_list.id,
          title: attendance_list.title,
          description: attendance_list.description,
          teacher_id: attendance_list.user_id,
          list_date: attendance_list.date,
          created_at: attendance_list.created_at,
          attendance_code: current_user.teacher? ? attendance_list.current_attendance_code : nil
        }
      end
    end
  end
end