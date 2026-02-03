class DepartmentsController < ApplicationController
  before_action :authenticate_user!

  # POST /department/switch
  def switch
    dept = Department.find_by(id: params[:department_id])
    if dept && (current_user.admin? || current_user.super_admin? || current_user.can_access_department?(dept) || dept.active?)
      session[:department_id] = dept.id
      message = "Switched to #{dept.name}"
    else
      message = "Unable to switch department"
    end

    redirect_back fallback_location: root_path, notice: message
  end
end
