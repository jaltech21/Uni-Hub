module Api
  module V1
    class SchedulesController < BaseController
      before_action :set_schedule, only: [:show, :enroll, :unenroll]

      def index
        schedules = schedule_scope.includes(:instructor, :schedule_participants).by_day_and_time
        render_success(schedules.map { |s| serialize_schedule(s) })
      end

      def browse
        enrolled_ids = current_user.enrolled_schedules.pluck(:id)
        schedules = Schedule.where.not(id: enrolled_ids)
                            .includes(:instructor, :department)
                            .by_day_and_time
        render_success(schedules.map { |s| serialize_schedule(s) })
      end

      def show
        if current_user.teacher? && @schedule.instructor_id != current_user.id
          return render_forbidden
        end
        render_success(serialize_schedule(@schedule, participantCount: true))
      end

      def enroll
        return render_forbidden unless current_user.student?
        return render_error("You are already enrolled in this class", status: :unprocessable_entity, code: "ALREADY_ENROLLED") if @schedule.has_participant?(current_user)

        if ScheduleParticipant.create(schedule: @schedule, user: current_user, role: "student")
          # Also keep enrollments table in sync for the primary course
          Enrollment.find_or_create_by(user: current_user, schedule: @schedule, status: "active")
          render_success(serialize_schedule(@schedule), status: :created)
        else
          participant = ScheduleParticipant.find_by(schedule: @schedule, user: current_user)
          render_error(
            "Failed to enroll in the class",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: participant&.errors&.messages
          )
        end
      end

      def unenroll
        @schedule.remove_participant(current_user)
        current_user.enrollments.find_by(schedule: @schedule)&.destroy
        render_message("Successfully unenrolled from the class.")
      end

      private

      def set_schedule
        @schedule = Schedule.find(params[:id])
      end

      def schedule_scope
        if current_user.teacher?
          Schedule.where(instructor_id: current_user.id)
        elsif current_user.admin?
          Schedule.all
        else
          current_user.enrolled_schedules
        end
      end

      def serialize_schedule(schedule, participantCount: false)
        payload = {
          id: schedule.id,
          title: schedule.title,
          start_time: schedule.start_time,
          end_time: schedule.end_time,
          day_of_week: schedule.day_of_week,
          day_name: schedule.day_name,
          student_id: current_user.id,
          course_id: schedule.course_schedule_ids.first || schedule.id,
          course_name: schedule.course,
          location: schedule.room,
          instructor_name: schedule.instructor&.full_name,
          status: schedule.status,
          created_at: schedule.created_at,
          updated_at: schedule.updated_at
        }
        if participantCount
          payload[:participants_count] = schedule.schedule_participants.active.count
          payload[:enrolled] = schedule.has_participant?(current_user)
        end
        payload
      end
    end
  end
end