module Api
  module V1
    class AttendanceListsController < BaseController
      before_action :require_teacher!, only: [:create]

      def index
        lists = if current_user.teacher?
                  current_user.attendance_lists.order(date: :desc, created_at: :desc)
                else
                  schedule_ids = current_user.enrolled_schedules.distinct.pluck(:id)
                  instructor_ids = Schedule.where(id: schedule_ids).distinct.pluck(:user_id, :instructor_id).flatten.compact
                  lists = AttendanceList.where(schedule_id: schedule_ids)
                  legacy = AttendanceList.where(user_id: instructor_ids)
                                          .where("date >= ?", Date.current)
                                          .where(schedule_id: nil)
                  lists.or(legacy).order(created_at: :desc)
                end
        render_success(lists.map { |l| serialize_list(l) })
      end

      def create
        list = current_user.attendance_lists.build(attendance_list_params)
        if list.save
          notify_enrolled_students(list)
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
        params.expect(attendance_list: {}).permit(:title, :description, :date, :schedule_id)
      end

      def notify_enrolled_students(attendance_list)
        return unless attendance_list.schedule.present?
        attendance_list.schedule.enrolled_students.find_each do |student|
          Notification.notify_attendance_created(student, attendance_list)
        end
      end

      def serialize_list(attendance_list)
        {
          id: attendance_list.id,
          title: attendance_list.title,
          description: attendance_list.description,
          teacher_id: attendance_list.user_id,
          schedule_id: attendance_list.schedule_id,
          list_date: attendance_list.date,
          created_at: attendance_list.created_at,
          attendance_code: current_user.teacher? ? attendance_list.current_attendance_code : nil
        }
      end
    end
  end
end
