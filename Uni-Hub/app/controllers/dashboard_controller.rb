class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :setup_user_dashboard

  def index
    # Personalized Dashboard with Widgets  
    @widget_service = widget_service
    @personalization = current_user.personalization_preferences
    
    # Legacy dashboard data for widgets that need it
    prepare_legacy_data
    
    # Usage analytics for recommendations
    track_dashboard_visit
  end
  
  def update_layout
    layout_params = params.require(:layout).permit(
      widgets: [:id, :grid_x, :grid_y, :width, :height, :position]
    )
    
    if layout_params[:widgets].present?
      layout_params[:widgets].each do |widget_data|
        widget = current_user.dashboard_widgets.find(widget_data[:id])
        widget.update!(
          grid_x: widget_data[:grid_x],
          grid_y: widget_data[:grid_y],
          width: widget_data[:width],
          height: widget_data[:height],
          position: widget_data[:position]
        )
      end
    end
    
    render json: { status: 'success', message: 'Dashboard layout updated' }
  rescue => e
    render json: { status: 'error', message: e.message }, status: :unprocessable_entity
  end
  
  def add_widget
    widget_params = params.require(:widget).permit(
      :widget_type, :title, :grid_x, :grid_y, :width, :height, :position,
      configuration: {}
    )
    
    widget = current_user.dashboard_widgets.build(widget_params)
    
    if widget.save
      widget_data = widget_service.get_widget_data(widget)
      render json: { 
        status: 'success', 
        widget: widget.as_json(include: [:user]),
        widget_data: widget_data
      }
    else
      render json: { 
        status: 'error', 
        errors: widget.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  def remove_widget
    widget = current_user.dashboard_widgets.find(params[:id])
    
    if widget.destroy
      render json: { status: 'success', message: 'Widget removed' }
    else
      render json: { status: 'error', message: 'Failed to remove widget' }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { status: 'error', message: 'Widget not found' }, status: :not_found
  end
  
  def configure_widget
    widget = current_user.dashboard_widgets.find(params[:id])
    config_params = params.require(:configuration).permit!
    
    widget.configuration = widget.configuration.merge(config_params.to_h)
    
    if widget.save
      widget_data = widget_service.get_widget_data(widget)
      render json: { 
        status: 'success', 
        widget: widget.as_json,
        widget_data: widget_data
      }
    else
      render json: { 
        status: 'error', 
        errors: widget.errors.full_messages 
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { status: 'error', message: 'Widget not found' }, status: :not_found
  end
  
  def refresh_widget
    widget = current_user.dashboard_widgets.find(params[:id])
    widget_data = widget_service.get_widget_data(widget, force_refresh: true)
    widget.refresh_data!
    
    render json: { 
      status: 'success', 
      widget_data: widget_data,
      last_refreshed: widget.last_refreshed
    }
  rescue ActiveRecord::RecordNotFound
    render json: { status: 'error', message: 'Widget not found' }, status: :not_found
  end
  
  def reset_dashboard
    current_user.dashboard_widgets.destroy_all
    UserDashboardWidget.create_default_widgets_for_user(current_user)
    
    redirect_to dashboard_path, notice: 'Dashboard has been reset to default layout'
  end
  
  # AJAX endpoint to refresh AI recommendations
  def refresh_ai_recommendations
    begin
      # Generate fresh recommendations
      ai_service = AiRecommendationService.new(current_user)
      recommendations = ai_service.generate_recommendations
      
      # Update any cached data if needed
      Rails.cache.delete("ai_recommendations_#{current_user.id}")
      
      render json: { 
        success: true, 
        message: 'Recommendations refreshed successfully' 
      }
    rescue => e
      Rails.logger.error "Failed to refresh AI recommendations: #{e.message}"
      render json: { 
        success: false, 
        error: 'Failed to refresh recommendations' 
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def setup_user_dashboard
    UserDashboardWidget.create_default_widgets_for_user(current_user) unless current_user.dashboard_widgets.exists?
  end
  
  def widget_service
    @widget_service ||= DashboardWidgetService.new(current_user)
  end
  
  def track_dashboard_visit
    # Track for analytics and recommendations
    Rails.logger.info "Dashboard visit: User #{current_user.id} at #{Time.current}"
  end
  
  def prepare_legacy_data
    if current_user.teacher?
      # Teacher Dashboard Data
      @total_assignments = Assignment.where(user_id: current_user.id).count
      @pending_submissions = Submission.joins(:assignment)
                                      .where(assignments: { user_id: current_user.id })
                                      .where(status: 'submitted')
                                      .count
      @graded_submissions = Submission.joins(:assignment)
                                     .where(assignments: { user_id: current_user.id })
                                     .where(status: 'graded')
                                     .count
      @recent_assignments = Assignment.where(user_id: current_user.id)
                                     .order(created_at: :desc)
                                     .limit(5)
      
      # Schedule Data
      @total_schedules = Schedule.where(user_id: current_user.id)
                                .or(Schedule.where(instructor_id: current_user.id))
                                .count
      @total_enrolled_students = Schedule.where(user_id: current_user.id)
                                        .or(Schedule.where(instructor_id: current_user.id))
                                        .sum { |s| s.student_count }
      @unique_courses = Schedule.where(user_id: current_user.id)
                               .or(Schedule.where(instructor_id: current_user.id))
                               .pluck(:course)
                               .uniq
                               .count
      @upcoming_schedules = Schedule.where(user_id: current_user.id)
                                   .or(Schedule.where(instructor_id: current_user.id))
                                   .where(recurring: true)
                                   .order(:day_of_week, :start_time)
                                   .limit(5)
    else
      # Student Dashboard Data
      @total_assignments = Assignment.count
      @pending_assignments = Assignment.where('due_date > ?', Time.current)
                                      .where.not(id: Submission.where(user_id: current_user.id).pluck(:assignment_id))
                                      .count
      @submitted_assignments = Submission.where(user_id: current_user.id, status: ['submitted', 'graded']).count
      @graded_submissions = Submission.where(user_id: current_user.id, status: 'graded').count
      @upcoming_assignments = Assignment.where('due_date > ?', Time.current)
                                       .order(:due_date)
                                       .limit(5)
      @recent_grades = Submission.where(user_id: current_user.id, status: 'graded')
                                .includes(:assignment)
                                .order(graded_at: :desc)
                                .limit(5)
      
      # Schedule Data
      @enrolled_schedules = current_user.enrolled_schedules.order(:day_of_week, :start_time)
      @total_classes = @enrolled_schedules.count
      @unique_courses = @enrolled_schedules.pluck(:course).uniq.count
      @today_schedules = @enrolled_schedules.where(day_of_week: Time.current.wday)
    end
  end
end
