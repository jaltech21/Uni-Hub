module Departments
  class SettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_department
    before_action :authorize_settings_access
    
    def show
      @settings = @department.settings
    end
    
    def edit
      @settings = @department.settings
    end
    
    def update
      @settings = @department.settings
      
      if @settings.update(settings_params)
        redirect_to department_settings_path(@department), notice: 'Settings updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    # Template management actions
    def add_template
      @settings = @department.settings
      template_type = params[:template_type]
      template_data = {
        'id' => SecureRandom.uuid,
        'name' => params[:template_name],
        'content' => params[:template_content],
        'created_at' => Time.current.to_s
      }
      
      if @settings.update_template(template_type, template_data)
        redirect_to department_settings_path(@department), notice: 'Template added successfully.'
      else
        redirect_to department_settings_path(@department), alert: 'Failed to add template.'
      end
    end
    
    def remove_template
      @settings = @department.settings
      template_type = params[:template_type]
      template_id = params[:template_id]
      
      if @settings.remove_template(template_type, template_id)
        redirect_to department_settings_path(@department), notice: 'Template removed successfully.'
      else
        redirect_to department_settings_path(@department), alert: 'Failed to remove template.'
      end
    end
    
    def preview
      @settings = @department.settings
      render layout: false
    end
    
    private
    
    def set_department
      @department = Department.find(params[:department_id])
    end
    
    def authorize_settings_access
      unless can_manage_department_settings?
        redirect_to root_path, alert: 'You are not authorized to manage department settings.'
      end
    end
    
    def can_manage_department_settings?
      return true if current_user.admin? || current_user.super_admin?
      return true if current_user.teacher? && current_user.teaching_departments.include?(@department)
      false
    end
    
    def settings_params
      params.require(:department_setting).permit(
        :primary_color,
        :secondary_color,
        :logo_url,
        :banner_url,
        :welcome_message,
        :footer_message,
        :default_assignment_visibility,
        :default_note_visibility,
        :default_quiz_visibility,
        :enable_announcements,
        :enable_content_sharing,
        :enable_peer_review,
        :enable_gamification,
        :notify_new_members,
        :notify_new_content,
        :notify_submissions
      )
    end
  end
end
