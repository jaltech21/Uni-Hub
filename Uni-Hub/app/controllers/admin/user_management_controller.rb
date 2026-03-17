class Admin::UserManagementController < ApplicationController
  layout 'admin'
  before_action :authenticate_admin!
  before_action :set_user, only: [:show, :edit, :update, :change_role, :blacklist, :unblacklist, :destroy]
  
  def index
    @users = User.includes(:department, :teaching_departments)
    
    # Apply filters
    @users = @users.by_role(params[:role]) if params[:role].present?
    @users = @users.where(department_id: params[:department_id]) if params[:department_id].present?
    @users = @users.blacklisted if params[:status] == 'blacklisted'
    @users = @users.active_users if params[:status] == 'active'
    @users = @users.search_by_name_or_email(params[:search]) if params[:search].present?
    
    # Pagination
    @users = @users.order(created_at: :desc).page(params[:page]).per(25)
    
    # For filters
    @departments = Department.order(:name)
    
    # Statistics
    @stats = {
      total_users: User.count,
      students: User.where(role: 'student').count,
      teachers: User.where(role: ['teacher', 'tutor']).count,
      admins: User.where(role: 'admin').count,
      blacklisted: User.blacklisted.count
    }
  end
  
  def show
    @audit_logs = AdminAuditLog.where(target_type: 'User', target_id: @user.id)
                                .order(created_at: :desc)
                                .limit(20)
    @enrollments = @user.enrollments.includes(:schedule).order(created_at: :desc).limit(10)
    @assignments = @user.created_assignments.includes(:schedule).order(created_at: :desc).limit(10) if @user.teacher?
  end
  
  def edit
    @departments = Department.order(:name)
  end
  
  def update
    if @user.update(user_params)
      log_admin_action('update_user', @user, { updated_fields: user_params.keys })
      redirect_to admin_user_management_path(@user), notice: 'User updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def change_role
    old_role = @user.role
    new_role = params[:new_role]
    
    if User::ROLES.include?(new_role) && @user.update(role: new_role)
      log_admin_action('change_role', @user, { 
        old_role: old_role, 
        new_role: new_role 
      })
      
      flash[:notice] = "User role changed from #{old_role} to #{new_role}."
    else
      flash[:alert] = "Failed to change user role."
    end
    
    redirect_to admin_user_management_path(@user)
  end
  
  def blacklist
    reason = params[:reason] || 'No reason provided'
    
    if @user.blacklist!(current_user, reason)
      log_admin_action('blacklist_user', @user, { reason: reason })
      flash[:notice] = "User has been blacklisted."
    else
      flash[:alert] = "Failed to blacklist user."
    end
    
    redirect_to admin_user_management_path(@user)
  end
  
  def unblacklist
    if @user.unblacklist!(current_user)
      log_admin_action('unblacklist_user', @user, { 
        blacklist_duration: (Time.current - @user.blacklisted_at).to_i 
      })
      flash[:notice] = "User has been removed from blacklist."
    else
      flash[:alert] = "Failed to unblacklist user."
    end
    
    redirect_to admin_user_management_path(@user)
  end
  
  def destroy
    user_email = @user.email
    
    if @user.destroy
      log_admin_action('delete_user', nil, { 
        deleted_user_email: user_email,
        deleted_user_id: @user.id 
      })
      flash[:notice] = "User #{user_email} has been deleted."
      redirect_to admin_user_management_index_path
    else
      flash[:alert] = "Failed to delete user."
      redirect_to admin_user_management_path(@user)
    end
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def authenticate_admin!
    unless user_signed_in? && current_user.admin?
      redirect_to new_admin_session_path, alert: 'Please sign in with an admin account.'
    end
  end
  
  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :department_id)
  end
  
  def log_admin_action(action, target, details = {})
    AdminAuditLog.create!(
      admin: current_user,
      action: action,
      target_type: target&.class&.name,
      target_id: target&.id,
      details: details,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
