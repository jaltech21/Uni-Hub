class GlobalSearchService
  attr_reader :query, :current_user, :filters, :limit
  
  def initialize(query:, current_user:, filters: {}, limit: 50)
    @query = query.to_s.strip
    @current_user = current_user
    @filters = filters.with_indifferent_access
    @limit = limit
  end
  
  def search
    return empty_results if query.blank?
    
    results = {}
    search_types = determine_search_types
    
    search_types.each do |type|
      results[type] = send("search_#{type}")
    end
    
    {
      query: query,
      total_results: results.values.sum(&:count),
      results: results,
      filters: active_filters,
      suggestions: generate_suggestions
    }
  end
  
  def quick_search(limit: 10)
    return empty_results if query.blank?
    
    {
      notes: search_notes.limit(3),
      assignments: search_assignments.limit(2),
      discussions: search_discussions.limit(2),
      users: search_users.limit(3),
      announcements: search_announcements.limit(2)
    }
  end
  
  private
  
  def determine_search_types
    if filters[:type].present?
      [filters[:type]]
    else
      %w[notes assignments discussions users announcements schedules quizzes]
    end
  end
  
  def search_notes
    scope = Note.includes(:user, :folder)
                .where(user: accessible_users)
    
    # Search in title and content
    scope = scope.where(
      "title ILIKE ? OR content ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where(folder_id: filters[:folder_id]) if filters[:folder_id].present?
    scope = scope.where(user_id: filters[:user_id]) if filters[:user_id].present?
    scope = scope.where('created_at >= ?', filters[:date_from]) if filters[:date_from].present?
    scope = scope.where('created_at <= ?', filters[:date_to]) if filters[:date_to].present?
    
    scope.order(updated_at: :desc).limit(limit)
  end
  
  def search_assignments
    scope = Assignment.includes(:user, :submissions)
    
    # For students, only show their assignments
    # For teachers/admins, show assignments they can access
    if current_user.student?
      scope = scope.joins(:submissions)
                   .where(submissions: { user: current_user })
                   .or(Assignment.where(user: current_user))
    elsif current_user.teacher?
      scope = scope.where(user: current_user)
                   .or(Assignment.joins(:user).where(users: { department: current_user.all_departments }))
    end
    
    scope = scope.where(
      "title ILIKE ? OR description ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where(user_id: filters[:user_id]) if filters[:user_id].present?
    scope = scope.where('due_date >= ?', filters[:date_from]) if filters[:date_from].present?
    scope = scope.where('due_date <= ?', filters[:date_to]) if filters[:date_to].present?
    scope = scope.where(subject: filters[:subject]) if filters[:subject].present?
    
    scope.order(created_at: :desc).limit(limit)
  end
  
  def search_discussions
    scope = Discussion.includes(:user, :discussion_posts)
                     .active
    
    scope = scope.where(
      "title ILIKE ? OR description ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
    
    # Also search in discussion posts
    post_discussion_ids = DiscussionPost.where("content ILIKE ?", "%#{query}%")
                                       .distinct
                                       .pluck(:discussion_id)
    
    if post_discussion_ids.any?
      scope = scope.or(Discussion.where(id: post_discussion_ids))
    end
    
    # Apply filters
    scope = scope.where(category: filters[:category]) if filters[:category].present?
    scope = scope.where(user_id: filters[:user_id]) if filters[:user_id].present?
    scope = scope.where('created_at >= ?', filters[:date_from]) if filters[:date_from].present?
    
    scope.order(updated_at: :desc).limit(limit)
  end
  
  def search_users
    return User.none unless current_user.teacher? || current_user.admin?
    
    scope = User.includes(:department)
                .where.not(id: current_user.id)
    
    # Search in name and email
    scope = scope.where(
      "email ILIKE ? OR CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, '')) ILIKE ?",
      "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where(role: filters[:role]) if filters[:role].present?
    scope = scope.where(department_id: filters[:department_id]) if filters[:department_id].present?
    
    scope.order(:email).limit(limit)
  end
  
  def search_announcements
    scope = Announcement.includes(:user, :department)
                       .published
                       .active
    
    # Filter by accessible departments
    if current_user.student?
      scope = scope.where(department: current_user.department)
    elsif current_user.teacher?
      scope = scope.where(department: current_user.all_departments)
    end
    
    scope = scope.where(
      "title ILIKE ? OR content ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where(priority: filters[:priority]) if filters[:priority].present?
    scope = scope.where(department_id: filters[:department_id]) if filters[:department_id].present?
    scope = scope.where('published_at >= ?', filters[:date_from]) if filters[:date_from].present?
    
    scope.order(published_at: :desc).limit(limit)
  end
  
  def search_schedules
    scope = Schedule.includes(:user, :department)
    
    # Filter by accessible schedules
    if current_user.student?
      scope = scope.joins(:schedule_participants)
                   .where(schedule_participants: { user: current_user })
                   .or(Schedule.where(user: current_user))
    elsif current_user.teacher?
      scope = scope.where(user: current_user)
                   .or(Schedule.where(instructor: current_user))
                   .or(Schedule.joins(:department).where(departments: { id: current_user.all_departments }))
    end
    
    scope = scope.where(
      "title ILIKE ? OR description ILIKE ? OR location ILIKE ?", 
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where('start_time >= ?', filters[:date_from]) if filters[:date_from].present?
    scope = scope.where('end_time <= ?', filters[:date_to]) if filters[:date_to].present?
    scope = scope.where(department_id: filters[:department_id]) if filters[:department_id].present?
    
    scope.order(:start_time).limit(limit)
  end
  
  def search_quizzes
    scope = Quiz.includes(:user)
    
    # Filter by accessible quizzes
    if current_user.student?
      scope = scope.where(published: true)
                   .joins(:user)
                   .where(users: { department: current_user.department })
    elsif current_user.teacher?
      scope = scope.where(user: current_user)
                   .or(Quiz.joins(:user).where(users: { department: current_user.all_departments }))
    end
    
    scope = scope.where(
      "title ILIKE ? OR description ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
    
    # Apply filters
    scope = scope.where(user_id: filters[:user_id]) if filters[:user_id].present?
    scope = scope.where(published: true) if filters[:published] == 'true'
    scope = scope.where('created_at >= ?', filters[:date_from]) if filters[:date_from].present?
    
    scope.order(created_at: :desc).limit(limit)
  end
  
  def accessible_users
    if current_user.student?
      [current_user]
    elsif current_user.teacher?
      User.where(department: current_user.all_departments)
    else
      User.all
    end
  end
  
  def active_filters
    filters.select { |_, v| v.present? }
  end
  
  def generate_suggestions
    return [] if query.length < 3
    
    suggestions = []
    
    # Add popular search terms
    popular_terms = [
      'assignments due this week',
      'course materials',
      'discussion forums',
      'grade reports',
      'study groups',
      'office hours',
      'exam schedules'
    ]
    
    suggestions += popular_terms.select { |term| term.include?(query.downcase) }
    
    # Add user-specific suggestions
    if current_user.student?
      suggestions += [
        "my assignments",
        "my grades",
        "my notes from #{query}",
        "discussions about #{query}"
      ]
    elsif current_user.teacher?
      suggestions += [
        "assignments I created",
        "my students",
        "#{query} submissions",
        "grade #{query}"
      ]
    end
    
    suggestions.uniq.first(5)
  end
  
  def empty_results
    {
      query: query,
      total_results: 0,
      results: {},
      filters: {},
      suggestions: []
    }
  end
end