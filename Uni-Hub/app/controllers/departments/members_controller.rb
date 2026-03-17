module Departments
  class MembersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_department
    before_action :authorize_member_management
    before_action :set_member, only: [:show, :edit, :update, :destroy, :change_role, :change_status]
    
    def index
      @members = @department.user_departments.includes(:user, :invited_by).active
      
      # Filter by role
      @members = @members.where(role: params[:role]) if params[:role].present?
      
      # Filter by status
      @members = @members.where(status: params[:status]) if params[:status].present?
      
      # Search by name or email
      if params[:query].present?
        user_ids = User.where("LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(email) LIKE ?",
                             "%#{params[:query].downcase}%",
                             "%#{params[:query].downcase}%",
                             "%#{params[:query].downcase}%").pluck(:id)
        @members = @members.where(user_id: user_ids)
      end
      
      @members = @members.order(joined_at: :desc).page(params[:page]).per(20)
      
      # Also get students directly assigned
      @students = @department.users.includes(:department)
      if params[:query].present?
        @students = @students.where("LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(email) LIKE ?",
                                   "%#{params[:query].downcase}%",
                                   "%#{params[:query].downcase}%",
                                   "%#{params[:query].downcase}%")
      end
      @students = @students.page(params[:student_page]).per(20)
    end
    
    def show
      @history = DepartmentMemberHistory.where(user: @member.user, department: @department).recent.limit(20)
    end
    
    def new
      @member = @department.user_departments.build
    end
    
    def create
      user = User.find_by(email: params[:email])
      
      if user.nil?
        redirect_to department_members_path(@department), alert: 'User not found with that email'
        return
      end
      
      @member = @department.user_departments.build(member_params.merge(
        user: user,
        invited_by: current_user,
        joined_at: Time.current
      ))
      
      if @member.save
        DepartmentMemberHistory.log_addition(user, @department, current_user, member_params.to_h)
        redirect_to department_members_path(@department), notice: 'Member added successfully'
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
    end
    
    def update
      old_role = @member.role
      old_status = @member.status
      
      if @member.update(member_params)
        # Log role change
        if old_role != @member.role
          DepartmentMemberHistory.log_role_change(@member.user, @department, current_user, old_role, @member.role)
        end
        
        # Log status change
        if old_status != @member.status
          DepartmentMemberHistory.log_status_change(@member.user, @department, current_user, old_status, @member.status)
        end
        
        redirect_to department_member_path(@department, @member), notice: 'Member updated successfully'
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @member.deactivate!
      DepartmentMemberHistory.log_removal(@member.user, @department, current_user, { reason: params[:reason] })
      redirect_to department_members_path(@department), notice: 'Member removed from department'
    end
    
    def import
      unless params[:csv_file].present?
        redirect_to department_members_path(@department), alert: 'Please select a CSV file'
        return
      end
      
      service = DepartmentMemberImportService.new(@department, params[:csv_file], current_user)
      
      if service.import
        summary = service.summary
        redirect_to department_members_path(@department),
                    notice: "Import completed: #{summary[:successful]} users added, #{summary[:failed]} errors"
      else
        summary = service.summary
        flash[:alert] = "Import failed: #{summary[:errors].first}"
        redirect_to department_members_path(@department)
      end
    end
    
    def bulk_add
      emails = params[:emails].to_s.split(/[,\n]/).map(&:strip).reject(&:blank?)
      role = params[:role] || 'member'
      
      added = 0
      errors = []
      
      emails.each do |email|
        user = User.find_by(email: email)
        if user.nil?
          errors << "#{email}: User not found"
          next
        end
        
        member = @department.user_departments.build(
          user: user,
          role: role,
          status: 'active',
          joined_at: Time.current,
          invited_by: current_user
        )
        
        if member.save
          DepartmentMemberHistory.log_addition(user, @department, current_user, { role: role, bulk_add: true })
          added += 1
        else
          errors << "#{email}: #{member.errors.full_messages.join(', ')}"
        end
      end
      
      if added > 0
        redirect_to department_members_path(@department), notice: "Added #{added} members. #{errors.size} errors."
      else
        redirect_to department_members_path(@department), alert: "Failed to add members: #{errors.join('; ')}"
      end
    end
    
    def bulk_remove
      member_ids = params[:member_ids] || []
      removed = 0
      
      member_ids.each do |id|
        member = @department.user_departments.find_by(id: id)
        next unless member
        
        member.deactivate!
        DepartmentMemberHistory.log_removal(member.user, @department, current_user, { bulk_remove: true })
        removed += 1
      end
      
      redirect_to department_members_path(@department), notice: "Removed #{removed} members"
    end
    
    def history
      @histories = @department.department_member_histories.includes(:user, :performed_by).recent.page(params[:page]).per(30)
    end
    
    def export
      members = @department.user_departments.includes(:user).active
      
      respond_to do |format|
        format.csv do
          csv_data = generate_csv(members)
          send_data csv_data, filename: "#{@department.code}_members_#{Date.today}.csv"
        end
      end
    end
    
    private
    
    def set_department
      @department = Department.find(params[:department_id])
    end
    
    def set_member
      @member = @department.user_departments.find(params[:id])
    end
    
    def authorize_member_management
      unless can_manage_department_members?
        redirect_to root_path, alert: 'You are not authorized to manage department members'
      end
    end
    
    def can_manage_department_members?
      return true if current_user.admin? || current_user.super_admin?
      return true if current_user.teacher? && current_user.teaching_departments.include?(@department)
      false
    end
    
    def member_params
      params.require(:user_department).permit(:role, :status, :notes)
    end
    
    def generate_csv(members)
      require 'csv'
      
      CSV.generate do |csv|
        csv << ['Email', 'Name', 'Role', 'Status', 'Joined At', 'Invited By']
        
        members.each do |member|
          csv << [
            member.user.email,
            member.user.full_name,
            member.role,
            member.status,
            member.joined_at&.strftime('%Y-%m-%d'),
            member.invited_by&.full_name
          ]
        end
      end
    end
  end
end
