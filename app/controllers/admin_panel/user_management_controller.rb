class Admin::UserManagementController < Admin::BaseController
  before_action :set_user, only: [:edit, :update]

  def index
    authorize User
    @users = User.includes(:department, :teaching_departments).order(created_at: :desc)
    
    # Filter by role if requested
    if params[:role].present? && User::ROLES.include?(params[:role])
      @users = @users.where(role: params[:role])
    end
    
    # Filter by department if requested
    if params[:department_id].present?
      @users = @users.where(department_id: params[:department_id])
    end
    
    # Search by name or email
    if params[:search].present?
      @users = @users.where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?", 
                           "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end
    
    @departments = Department.active.ordered
  end

  def edit
    authorize @user
    @departments = Department.active.ordered
    @available_departments = Department.active.ordered - @user.teaching_departments
  end

  def update
    authorize @user
    # Handle department assignments for tutors
    if params[:user][:teaching_department_ids].present? && (@user.tutor? || @user.teacher?)
      department_ids = params[:user][:teaching_department_ids].reject(&:blank?)
      @user.teaching_departments = Department.where(id: department_ids)
    end
    
    if @user.update(user_params)
      redirect_to admin_user_management_index_path, notice: "User '#{@user.full_name}' was successfully updated."
    else
      @departments = Department.active.ordered
      @available_departments = Department.active.ordered - @user.teaching_departments
      render :edit, status: :unprocessable_entity
    end
  end

  def assign_department
    @user = User.find(params[:id])
    authorize @user, :assign_department?
    department = Department.find(params[:department_id])
    
    @user.update(department: department)
    redirect_to admin_user_management_index_path, notice: "#{@user.full_name} assigned to #{department.name}"
  end

  def change_role
    @user = User.find(params[:id])
    authorize @user, :change_role?
    new_role = params[:role]
    
    if User::ROLES.include?(new_role)
      @user.update(role: new_role)
      redirect_to admin_user_management_index_path, notice: "#{@user.full_name}'s role changed to #{new_role.titleize}"
    else
      redirect_to admin_user_management_index_path, alert: "Invalid role"
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_user_management_index_path, alert: "User not found."
  end

  def user_params
    params.require(:user).permit(:role, :department_id, :first_name, :last_name)
  end
end
