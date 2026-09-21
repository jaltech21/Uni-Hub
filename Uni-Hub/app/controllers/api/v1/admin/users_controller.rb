module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: [:update, :change_role, :blacklist, :unblacklist, :reset_password]

        def index
          users = User.includes(:department, :teaching_departments)
          users = users.by_role(params[:role]) if params[:role].present?
          users = users.where(department_id: params[:department_id]) if params[:department_id].present?
          users = users.blacklisted if params[:status] == "blacklisted"
          users = users.active_users if params[:status] == "active"
          users = users.search_by_name_or_email(params[:search]) if params[:search].present?

          paginated = paginate(users.order(created_at: :desc))
          render_success(paginated.map { |u| serialize_user(u) }, meta: pagination_meta(paginated))
        end

        def update
          if @user.update(user_params)
            render_success(serialize_user(@user))
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @user.errors.messages
            )
          end
        end

        def change_role
          new_role = params[:role]
          if %w[student teacher tutor admin].include?(new_role) && @user.update(role: new_role)
            render_success(serialize_user(@user))
          else
            render_error("Failed to change user role", status: :unprocessable_entity, code: "VALIDATION_ERROR", errors: @user.errors.messages)
          end
        end

        def blacklist
          @user.blacklist!(current_user, params[:reason] || "No reason provided")
          render_success(serialize_user(@user))
        end

        def unblacklist
          @user.unblacklist!(current_user)
          render_success(serialize_user(@user))
        end

        def reset_password
          temp_password = SecureRandom.hex(6)
          @user.reset_password!(temp_password, temp_password)

          if @user.valid?
            NotificationService.notify_password_reset(@user, temp_password)
            render_success({ user_id: @user.id, temporary_password: temp_password, message: "Password reset successfully" })
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @user.errors.messages
            )
          end
        end

        private

        def set_user
          @user = User.find(params[:id])
        end

        def user_params
          params.expect(user: {}).permit(:first_name, :last_name, :email, :username, :role, :department_id)
        end

        def serialize_user(user)
          {
            id: user.id,
            first_name: user.first_name,
            last_name: user.last_name,
            email: user.email,
            username: user.username,
            role: user.role,
            department_id: user.department_id,
            department_name: user.department&.name,
            active: user.active_for_authentication?,
            blacklisted: user.blacklisted?,
            created_at: user.created_at,
            updated_at: user.updated_at
          }
        end
      end
    end
  end
end