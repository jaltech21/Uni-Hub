class ContentSharingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content
  before_action :authorize_sharing
  
  def show
    @sharing_service = ContentSharingService.new(@content, current_user)
    @shared_departments = @sharing_service.shared_departments
    @available_departments = get_available_departments
    @sharing_history = @sharing_service.sharing_history.limit(20)
  end
  
  def create
    department_ids = params[:department_ids]&.reject(&:blank?) || []
    permission_level = params[:permission_level] || 'view'
    
    @sharing_service = ContentSharingService.new(@content, current_user)
    results = @sharing_service.share_with_departments(department_ids, permission_level: permission_level)
    
    if results[:failed].empty?
      redirect_to content_sharing_path(content_type: @content_type, content_id: @content.id),
                  notice: "Successfully shared with #{results[:success].count} department(s)."
    else
      flash.now[:alert] = "Some departments failed: #{results[:failed].map { |f| f[:errors].join(', ') }.join('; ')}"
      @shared_departments = @sharing_service.shared_departments
      @available_departments = get_available_departments
      render :show
    end
  end
  
  def destroy
    department = Department.find(params[:department_id])
    @sharing_service = ContentSharingService.new(@content, current_user)
    
    results = @sharing_service.unshare_from_departments([department.id])
    
    if results[:failed].empty?
      redirect_to content_sharing_path(content_type: @content_type, content_id: @content.id),
                  notice: "Successfully unshared from #{department.name}."
    else
      redirect_to content_sharing_path(content_type: @content_type, content_id: @content.id),
                  alert: "Failed to unshare: #{results[:failed].first[:errors].join(', ')}"
    end
  end
  
  def update_permission
    department = Department.find(params[:department_id])
    new_permission = params[:permission_level]
    
    @sharing_service = ContentSharingService.new(@content, current_user)
    
    if @sharing_service.update_permission(department.id, new_permission)
      redirect_to content_sharing_path(content_type: @content_type, content_id: @content.id),
                  notice: "Permission updated for #{department.name}."
    else
      redirect_to content_sharing_path(content_type: @content_type, content_id: @content.id),
                  alert: "Failed to update permission."
    end
  end
  
  private
  
  def set_content
    @content_type = params[:content_type]
    @content_id = params[:content_id] || params[:id]
    
    @content = case @content_type
               when 'assignment', 'assignments'
                 Assignment.find(@content_id)
               when 'note', 'notes'
                 Note.find(@content_id)
               when 'quiz', 'quizzes'
                 Quiz.find(@content_id)
               else
                 raise "Invalid content type: #{@content_type}"
               end
  end
  
  def authorize_sharing
    # Only the content creator, teachers, and admins can manage sharing
    unless @content.user == current_user || current_user.teacher? || current_user.tutor? || current_user.admin? || current_user.super_admin?
      redirect_to root_path, alert: 'You are not authorized to manage sharing for this content.'
    end
  end
  
  def get_available_departments
    if current_user.admin? || current_user.super_admin?
      # Admins can share with any department
      Department.active.ordered
    elsif current_user.teacher? || current_user.tutor?
      # Teachers/tutors can share with their departments
      Department.active.where(id: current_user.teaching_departments.pluck(:id))
    else
      # Regular users can only share with their own department
      Department.active.where(id: current_user.department_id)
    end
  end
end
