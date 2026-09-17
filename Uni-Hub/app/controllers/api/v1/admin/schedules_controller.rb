module Api
  module V1
    module Admin
      class SchedulesController < BaseController
        before_action :set_schedule, only: [:show, :update, :destroy, :approve, :cancel]

        def index
          schedules = Schedule.all
          schedules = schedules.for_instructor(params[:instructor_id]) if params[:instructor_id].present?
          schedules = schedules.for_day(params[:day_of_week].to_i) if params[:day_of_week].present?
          schedules = schedules.where(department_id: params[:department_id]) if params[:department_id].present?
          render_success(schedules.includes(:instructor, :department).by_day_and_time.map { |s| serialize_schedule(s) })
        end

        def show
          render_success(serialize_schedule(@schedule, detail: true))
        end

        def create
          schedule = Schedule.new(schedule_params)
          if schedule.save
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

        def update
          if @schedule.update(schedule_params)
            render_success(serialize_schedule(@schedule))
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @schedule.errors.messages
            )
          end
        end

        def destroy
          @schedule.destroy
          render_message("Schedule deleted successfully")
        end

        def approve
          @schedule.update!(approved_at: Time.current, approved_by_id: current_user.id)
          render_success(serialize_schedule(@schedule))
        end

        def cancel
          @schedule.update!(cancelled_at: Time.current, cancelled_by_id: current_user.id, cancellation_reason: params[:reason])
          render_success(serialize_schedule(@schedule))
        end

        private

        def set_schedule
          @schedule = Schedule.find(params[:id])
        end

        def schedule_params
          params.expect(schedule: {}).permit(
            :title, :course, :day_of_week, :start_time, :end_time,
            :room, :instructor_id, :user_id, :recurring, :color, :description
          )
        end

        def serialize_schedule(schedule, detail: false)
          payload = {
            id: schedule.id,
            title: schedule.title,
            course: schedule.course,
            day_of_week: schedule.day_of_week,
            day_name: schedule.day_name,
            start_time: schedule.start_time,
            end_time: schedule.end_time,
            room: schedule.room,
            instructor_id: schedule.instructor_id,
            instructor_name: schedule.instructor&.full_name,
            status: schedule.status,
            created_at: schedule.created_at,
            updated_at: schedule.updated_at
          }
          if detail
            payload[:recurring] = schedule.recurring
            payload[:color] = schedule.color
            payload[:description] = schedule.description
            payload[:participants_count] = schedule.schedule_participants.active.count
            payload[:approved_by] = User.find_by(id: schedule.approved_by_id)&.full_name
            payload[:cancelled_by] = User.find_by(id: schedule.cancelled_by_id)&.full_name
            payload[:cancellation_reason] = schedule.cancellation_reason
          end
          payload
        end
      end
    end
  end
end