module Api
  module V1
    module Admin
      class DepartmentsController < BaseController
        before_action :set_department, only: [:show, :update, :destroy, :toggle_active]

        def index
          departments = Department.all
          departments = departments.active if params[:active] == "true"
          departments = departments.where("name ILIKE ? OR code ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
          render_success(departments.ordered.includes(:users).map { |d| serialize_department(d) })
        end

        def show
          render_success(serialize_department(@department, detail: true))
        end

        def create
          department = Department.new(department_params)
          if department.save
            render_success(serialize_department(department), status: :created)
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: department.errors.messages
            )
          end
        end

        def update
          if @department.update(department_params)
            render_success(serialize_department(@department))
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @department.errors.messages
            )
          end
        end

        def destroy
          @department.destroy
          render_message("Department deleted successfully")
        end

        def toggle_active
          @department.update!(active: !@department.active)
          render_success(serialize_department(@department))
        end

        private

        def set_department
          @department = Department.find(params[:id])
        end

        def department_params
          params.expect(department: {}).permit(:name, :code, :university_id, :active)
        end

        def serialize_department(department, detail: false)
          payload = {
            id: department.id,
            name: department.name,
            code: department.code,
            active: department.active,
            member_count: department.member_count,
            created_at: department.created_at,
            updated_at: department.updated_at
          }
          if detail
            payload[:university_id] = department.university_id
            payload[:users] = department.users.limit(50).map do |u|
              { id: u.id, first_name: u.first_name, last_name: u.last_name, email: u.email, role: u.role }
            end
          end
          payload
        end
      end
    end
  end
end