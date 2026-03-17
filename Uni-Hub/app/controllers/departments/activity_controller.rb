class Departments::ActivityController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department
  before_action :ensure_department_member

  def index
    authorize @department, :show?
    
    @activity_service = ActivityFeedService.new(@department, params)
    @activities = @activity_service.load_activities
    @activity_types = @activity_service.activity_types_summary
    @filter_options = build_filter_options
    @recent_stats = @activity_service.recent_activity_stats
    @most_active_users = @activity_service.most_active_users
    
    respond_to do |format|
      format.html
      format.json { render json: format_activities_for_json(@activities) }
    end
  end

  def filter
    authorize @department, :show?
    
    @activity_service = ActivityFeedService.new(@department, params)
    @activities = @activity_service.load_activities
    
    respond_to do |format|
      format.json { render json: format_activities_for_json(@activities) }
      format.html { redirect_to department_activity_index_path(@department) }
    end
  end

  def load_more
    authorize @department, :show?
    
    page = params[:page]&.to_i || 1
    @activity_service = ActivityFeedService.new(@department, params)
    @activities = @activity_service.load_activities(page: page)
    
    respond_to do |format|
      format.json { render json: format_activities_for_json(@activities) }
    end
  end

  private

  def set_department
    @department = Department.find(params[:department_id])
  end

  def ensure_department_member
    unless current_user.admin? || @department.users.include?(current_user)
      redirect_to departments_path, alert: 'You do not have access to this department.'
    end
  end





  def build_filter_options
    {
      users: @department.users.select(:id, :first_name, :last_name, :role).map do |user|
        {
          id: user.id,
          name: "#{user.first_name} #{user.last_name}",
          role: user.role
        }
      end,
      date_presets: [
        { key: 'today', label: 'Today', days: 0 },
        { key: 'week', label: 'This Week', days: 7 },
        { key: 'month', label: 'This Month', days: 30 },
        { key: 'quarter', label: 'This Quarter', days: 90 }
      ]
    }
  end



  def format_activities_for_json(activities)
    {
      activities: activities.map do |activity|
        activity.merge({
          user_name: "#{activity[:user].first_name} #{activity[:user].last_name}",
          user_avatar: activity[:user].try(:avatar) || nil,
          formatted_time: time_ago_in_words(activity[:timestamp]),
          formatted_date: activity[:timestamp].strftime('%B %d, %Y at %I:%M %p')
        })
      end,
      has_more: activities.length >= 20,
      total_count: load_activities.length
    }
  end


end