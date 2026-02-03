class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_department
  helper_method :current_department

  layout :set_layout

  # Pundit: Handle unauthorized access
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_layout
    user_signed_in? ? "dashboard" : "application"
  end

  # Sets the current department for the session and request.
  # Priority:
  # 1. session[:department_id] if set (user switched)
  # 2. student's department (user.department)
  # 3. tutor's first teaching department
  # 4. first active department as fallback
  def set_current_department
    return unless user_signed_in?

    dept = nil
    if session[:department_id].present?
      dept = Department.find_by(id: session[:department_id])
    end

    if dept.nil?
      if current_user.student?
        dept = current_user.department
      elsif current_user.tutor? || current_user.teacher?
        dept = current_user.teaching_departments.first
      elsif current_user.admin? || current_user.super_admin?
        # admins default to first active department (can switch)
        dept = Department.active.ordered.first
      end
    end

    # Fallback to any active department
    dept ||= Department.active.ordered.first

    @current_department = dept
    # keep session in sync when user manually switches
    session[:department_id] = dept.id if dept && session[:department_id].nil?
  end

  def current_department
    @current_department
  end
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :username, :role, :department_id, :phone, :student_id])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :username, :phone, :student_id, :profile_picture])
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
