module Api
  module V1
    class EnrollmentsController < BaseController
      before_action :set_enrollment, only: [:destroy]

      def index
        enrollments = if current_user.student?
                        current_user.enrollments.includes(:schedule).order(created_at: :desc)
                      elsif current_user.teacher?
                        Enrollment.joins(:schedule)
                                  .where(schedules: { instructor_id: current_user.id })
                                  .includes(:user, :schedule)
                                  .order(created_at: :desc)
                      else
                        Enrollment.includes(:user, :schedule).order(created_at: :desc)
                      end
        render_success(enrollments.map { |e| serialize_enrollment(e) })
      end

      def create
        enrollment = current_user.enrollments.build(enrollment_params)

        if enrollment.save
          render_success(serialize_enrollment(enrollment), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: enrollment.errors.messages
          )
        end
      end

      def destroy
        if @enrollment.user_id != current_user.id && !current_user.admin?
          return render_forbidden
        end
        @enrollment.destroy
        render_message("Successfully dropped #{@enrollment.schedule.title}")
      end

      def capacity
        schedule = Schedule.find(params[:schedule_id])
        render_success({
          enrolled: schedule.active_enrollments.count,
          available_slots: schedule.available_slots,
          has_capacity: schedule.has_capacity?,
          percentage: schedule.enrollment_percentage
        })
      end

      private

      def set_enrollment
        @enrollment = Enrollment.find(params[:id])
      end

      def enrollment_params
        params.expect(enrollment: {}).permit(:schedule_id, :status)
      end

      def serialize_enrollment(enrollment)
        {
          id: enrollment.id,
          student_id: enrollment.user_id,
          schedule_id: enrollment.schedule_id,
          status: enrollment.status,
          schedule_title: enrollment.schedule&.title,
          created_at: enrollment.created_at
        }
      end
    end
  end
end