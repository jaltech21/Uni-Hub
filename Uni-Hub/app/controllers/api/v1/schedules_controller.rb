module Api
  module V1
    class SchedulesController < BaseController
      before_action :set_schedule, only: [:show, :enroll, :unenroll]

      def index
        schedules = schedule_scope.includes(:instructor, :schedule_participants).by_day_and_time
        render_success(schedules.map { |s| serialize_schedule(s) })
      end

      def create
        schedule = build_personal_schedule
        if schedule.save
          # Auto-enroll the creator so the schedule appears on their dashboard.
          ScheduleParticipant.find_or_create_by(schedule: schedule, user: current_user, role: "student")
          Enrollment.find_or_create_by(user: current_user, schedule: schedule, status: "active")

          NotificationService.create_notification(
            user: current_user,
            title: "Schedule added",
            message: "#{schedule.title} was added to your schedule.",
            notification_type: "schedule_created",
            related_object: schedule
          )
          render_success(serialize_schedule(schedule), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: schedule.errors.messages
          )
        end
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

      def build_personal_schedule
        day_index = parse_day_of_week(schedule_params[:day_of_week])
        start_time = parse_time(schedule_params[:start_time])
        end_time = parse_time(schedule_params[:end_time])

        Schedule.new(
          user: current_user,
          instructor: current_user,
          title: schedule_params[:title].to_s.strip,
          course: schedule_params[:course].presence || "Personal",
          day_of_week: day_index,
          start_time: start_time,
          end_time: end_time,
          room: schedule_params[:room].presence || "Study room",
          description: schedule_params[:description],
          color: schedule_params[:color].presence || "#3b5bfd",
          recurring: schedule_params[:recurring].nil? ? true : schedule_params[:recurring]
        )
      end

      # Accepts 0..6 integers or English day names ("Monday", "mon").
      def parse_day_of_week(value)
        return nil if value.blank?
        integer = value.to_i
        return integer if value.to_s == value.to_i.to_s && integer.between?(0, 6)

        index = Date::DAYNAMES.index { |d| d.casecmp?(value.to_s) }
        return nil if index.nil?
        index
      end

      def parse_time(value)
        return nil if value.blank?
        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def schedule_params
        params.permit(:title, :course, :day_of_week, :start_time, :end_time, :room, :description, :color, :recurring)
      end

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