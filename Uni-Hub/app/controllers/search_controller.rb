class SearchController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @recent_searches = current_user.recent_searches.limit(5) if current_user.respond_to?(:recent_searches)
    @popular_searches = get_popular_searches
    @search_filters = build_search_filters
  end

  def results
    @query = params[:q].to_s.strip
    @filters = search_params.except(:q, :page)
    @page = params[:page].to_i.positive? ? params[:page].to_i : 1
    @per_page = params[:per_page].to_i.positive? ? params[:per_page].to_i : 20
    
    if @query.present?
      search_service = GlobalSearchService.new(
        query: @query,
        current_user: current_user,
        filters: @filters,
        limit: @per_page
      )
      
      @search_results = search_service.search
      
      # Save search query for recent searches
      save_search_query(@query) if @search_results[:total_results] > 0
      
      # Track analytics
      track_search_analytics(@query, @search_results[:total_results])
    else
      @search_results = { query: @query, total_results: 0, results: {}, suggestions: [] }
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @search_results }
    end
  end

  def suggestions
    @query = params[:q].to_s.strip
    
    if @query.length >= 2
      search_service = GlobalSearchService.new(
        query: @query,
        current_user: current_user,
        limit: 5
      )
      
      @suggestions = search_service.quick_search
      @query_suggestions = search_service.send(:generate_suggestions)
    else
      @suggestions = {}
      @query_suggestions = []
    end
    
    respond_to do |format|
      format.json do
        render json: {
          suggestions: @suggestions,
          query_suggestions: @query_suggestions,
          query: @query
        }
      end
    end
  end
  
  private
  
  def search_params
    params.permit(:q, :type, :user_id, :folder_id, :department_id, :category, 
                  :subject, :role, :priority, :published, :date_from, :date_to, 
                  :page, :per_page)
  end
  
  def get_popular_searches
    # This would typically come from analytics/tracking
    [
      'assignments due this week',
      'course materials',
      'discussion forums',
      'study guides',
      'exam schedules'
    ]
  end
  
  def build_search_filters
    filters = {}
    
    # Content types
    filters[:types] = [
      { value: 'notes', label: 'Notes', icon: 'document-text' },
      { value: 'assignments', label: 'Assignments', icon: 'clipboard-list' },
      { value: 'discussions', label: 'Discussions', icon: 'chat-bubble-left-right' },
      { value: 'announcements', label: 'Announcements', icon: 'megaphone' },
      { value: 'schedules', label: 'Schedules', icon: 'calendar' },
      { value: 'quizzes', label: 'Quizzes', icon: 'academic-cap' }
    ]
    
    # Add users for teachers/admins
    if current_user.teacher? || current_user.admin?
      filters[:types] << { value: 'users', label: 'Users', icon: 'users' }
    end
    
    # Departments (for teachers/admins)
    if current_user.teacher? || current_user.admin?
      filters[:departments] = Department.all.map { |d| { value: d.id, label: d.name } }
    end
    
    # User roles (for admins)
    if current_user.admin?
      filters[:roles] = User.roles.keys.map { |role| { value: role, label: role.humanize } }
    end
    
    # Discussion categories
    if defined?(Discussion)
      filters[:categories] = Discussion.distinct.pluck(:category).compact.map do |cat|
        { value: cat, label: cat.humanize }
      end
    end
    
    # Assignment subjects
    if defined?(Assignment)
      filters[:subjects] = Assignment.distinct.pluck(:subject).compact.map do |subject|
        { value: subject, label: subject }
      end
    end
    
    filters
  end
  
  def save_search_query(query)
    # This would save to a recent_searches table if implemented
    # For now, we'll use session storage
    session[:recent_searches] ||= []
    session[:recent_searches].unshift(query)
    session[:recent_searches] = session[:recent_searches].uniq.first(10)
  end
  
  def track_search_analytics(query, results_count)
    # This would typically go to an analytics service
    Rails.logger.info "SEARCH: User #{current_user.id} searched for '#{query}' - #{results_count} results"
  end
end
