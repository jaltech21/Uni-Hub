module Api
  module V1
    class AttendanceListsController < BaseController
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

      private

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