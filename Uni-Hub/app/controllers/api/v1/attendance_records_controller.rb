module Api
  module V1
    class AttendanceRecordsController < BaseController
      def index
        records = if current_user.teacher?
                    AttendanceRecord.includes(:user, :attendance_list)
                                    .where(attendance_lists: { user_id: current_user.id })
                                    .order(created_at: :desc)
                  else
                    current_user.attendance_records.includes(:attendance_list)
                                .order(created_at: :desc)
                  end
        render_success(records.map { |r| serialize_record(r) })
      end

      def create
        attendance_list = AttendanceList.find(params[:attendance_list_id])
        return render_error("Attendance code is required", status: :unprocessable_entity, code: "VALIDATION_ERROR") if params[:code].blank?

        unless attendance_list.verify_attendance_code(params[:code])
          return render_error("Invalid or expired attendance code", status: :unprocessable_entity, code: "INVALID_CODE")
        end

        existing = attendance_list.attendance_records.find_by(user: current_user)
        return render_error("Attendance already marked", status: :unprocessable_entity, code: "ALREADY_MARKED") if existing.present?

        record = attendance_list.attendance_records.build(user: current_user, present: true)
        if record.save
          render_success(serialize_record(record), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: record.errors.messages
          )
        end
      end

      private

      def serialize_record(record)
        {
          id: record.id,
          attendance_list_id: record.attendance_list_id,
          list_title: record.attendance_list&.title,
          list_date: record.attendance_list&.date,
          student_id: record.user_id,
          student_name: record.user&.full_name,
          present: record.present,
          created_at: record.created_at,
          updated_at: record.updated_at
        }
      end
    end
  end
end