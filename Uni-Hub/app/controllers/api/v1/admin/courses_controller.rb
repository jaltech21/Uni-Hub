module Api
  module V1
    module Admin
      class CoursesController < BaseController
        before_action :set_course, only: [:show, :update, :destroy, :toggle_active]

        def index
          courses = Course.all
          courses = courses.active if params[:active] == "true"
          courses = courses.where(department_id: params[:department_id]) if params[:department_id].present?
          courses = courses.where("name ILIKE ? OR code ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
          render_success(courses.includes(:department).order(:name).map { |c| serialize_course(c) })
        end

        def show
          render_success(serialize_course(@course, detail: true))
        end

        def create
          course = Course.new(course_params)
          if course.save
            render_success(serialize_course(course), status: :created)
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: course.errors.messages
            )
          end
        end

        def update
          if @course.update(course_params)
            render_success(serialize_course(@course))
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @course.errors.messages
            )
          end
        end

        def destroy
          @course.destroy
          render_message("Course deleted successfully")
        end

        def toggle_active
          @course.update!(active: !@course.active)
          render_success(serialize_course(@course))
        end

        private

        def set_course
          @course = Course.find(params[:id])
        end

        def course_params
          params.expect(course: {}).permit(
            :name, :code, :department_id, :credits, :duration_weeks,
            :level, :delivery_method, :tuition_cost, :max_students,
            :active, :description
          )
        end

        def serialize_course(course, detail: false)
          payload = {
            id: course.id,
            name: course.name,
            code: course.code,
            full_code: course.full_code,
            department_id: course.department_id,
            department_name: course.department&.name,
            credits: course.credits,
            duration_weeks: course.duration_weeks,
            level: course.level,
            delivery_method: course.delivery_method,
            tuition_cost: course.tuition_cost,
            max_students: course.max_students,
            active: course.active,
            created_at: course.created_at,
            updated_at: course.updated_at
          }
          if detail
            payload[:description] = course.description
            payload[:schedules_count] = course.course_schedules.count
            payload[:assignments_count] = course.assignments.count
          end
          payload
        end
      end
    end
  end
end