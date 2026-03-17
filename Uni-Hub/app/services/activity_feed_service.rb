class ActivityFeedService
  attr_reader :department, :filters

  def initialize(department, filters = {})
    @department = department
    @filters = filters.with_indifferent_access
  end

  def load_activities(page: 1, per_page: 20)
    activities = []
    
    # Apply date filters
    date_from = parse_date(filters[:date_from])
    date_to = parse_date(filters[:date_to])
    
    # Apply user filter
    user_filter = filters[:user_id].present? ? filters[:user_id] : nil
    
    # Apply activity type filters
    activity_types = parse_activity_types(filters[:activity_types])
    
    # Collect activities from different sources
    activities.concat(announcement_activities(date_from, date_to, user_filter)) if activity_types.include?('announcements')
    activities.concat(content_sharing_activities(date_from, date_to, user_filter)) if activity_types.include?('content_sharing')
    activities.concat(member_change_activities(date_from, date_to, user_filter)) if activity_types.include?('member_changes')
    activities.concat(assignment_activities(date_from, date_to, user_filter)) if activity_types.include?('assignments')
    activities.concat(quiz_activities(date_from, date_to, user_filter)) if activity_types.include?('quizzes')
    activities.concat(note_activities(date_from, date_to, user_filter)) if activity_types.include?('notes')
    
    # Sort by timestamp (newest first) and paginate
    activities.sort_by! { |activity| -activity[:timestamp].to_i }
    
    offset = (page - 1) * per_page
    activities[offset, per_page] || []
  end

  def activity_types_summary
    [
      {
        key: 'announcements',
        label: 'Announcements',
        icon: '📢',
        count: department.announcements.count,
        color: 'blue'
      },
      {
        key: 'content_sharing',
        label: 'Content Sharing',
        icon: '🔗',
        count: department.content_sharing_histories.count,
        color: 'green'
      },
      {
        key: 'member_changes',
        label: 'Member Changes',
        icon: '👥',
        count: department.department_member_histories.count,
        color: 'purple'
      },
      {
        key: 'assignments',
        label: 'Assignments',
        icon: '📝',
        count: department.assignments.count,
        color: 'orange'
      },
      {
        key: 'quizzes',
        label: 'Quizzes',
        icon: '❓',
        count: department.quizzes.count,
        color: 'yellow'
      },
      {
        key: 'notes',
        label: 'Notes',
        icon: '📋',
        count: department.notes.count,
        color: 'indigo'
      }
    ]
  end

  def recent_activity_stats(days = 7)
    cutoff_date = days.days.ago
    
    {
      announcements: department.announcements.where('created_at > ?', cutoff_date).count,
      content_shares: department.content_sharing_histories.where('created_at > ?', cutoff_date).count,
      member_changes: department.department_member_histories.where('created_at > ?', cutoff_date).count,
      assignments: department.assignments.where('created_at > ?', cutoff_date).count,
      quizzes: department.quizzes.where('created_at > ?', cutoff_date).count,
      notes: department.notes.where('created_at > ?', cutoff_date).count
    }
  end

  def most_active_users(limit = 5)
    # Aggregate activity across all types
    user_activity = Hash.new(0)
    
    # Count announcements
    department.announcements.includes(:user).each do |announcement|
      user_activity[announcement.user] += 1
    end
    
    # Count content sharing
    department.content_sharing_histories.includes(:shared_by).each do |share|
      user_activity[share.shared_by] += 1
    end
    
    # Count assignments
    department.assignments.includes(:user).each do |assignment|
      user_activity[assignment.user] += 1
    end
    
    # Count quizzes
    department.quizzes.includes(:user).each do |quiz|
      user_activity[quiz.user] += 1
    end
    
    # Count notes
    department.notes.includes(:user).each do |note|
      user_activity[note.user] += 1
    end
    
    # Sort and return top users
    user_activity.sort_by { |user, count| -count }.first(limit).map do |user, count|
      {
        user: user,
        activity_count: count,
        name: "#{user.first_name} #{user.last_name}",
        role: user.role
      }
    end
  end

  private

  def announcement_activities(date_from, date_to, user_filter)
    announcements = department.announcements.includes(:user)
    announcements = apply_date_filter(announcements, date_from, date_to)
    announcements = announcements.where(user_id: user_filter) if user_filter
    
    announcements.map do |announcement|
      {
        id: "announcement_#{announcement.id}",
        type: 'announcement',
        title: "New Announcement: #{announcement.title}",
        description: truncate_content(announcement.content, 150),
        user: announcement.user,
        timestamp: announcement.created_at,
        icon: '📢',
        color: 'blue',
        url: '/announcements/' + announcement.id.to_s,
        metadata: {
          published: announcement.try(:published?) || false,
          priority: announcement.try(:priority) || 'normal'
        }
      }
    end
  end

  def content_sharing_activities(date_from, date_to, user_filter)
    content_shares = department.content_sharing_histories.includes(:shared_by, :shareable)
    content_shares = apply_date_filter(content_shares, date_from, date_to)
    content_shares = content_shares.where(shared_by_id: user_filter) if user_filter
    
    content_shares.map do |share|
      content_title = extract_content_title(share.shareable)
      
      {
        id: "content_#{share.id}",
        type: 'content_sharing',
        title: "Shared #{share.shareable_type}: #{content_title}",
        description: "#{share.shared_by.first_name} #{share.shared_by.last_name} shared content with the department",
        user: share.shared_by,
        timestamp: share.created_at,
        icon: content_type_icon(share.shareable_type),
        color: 'green',
        url: content_url(share.shareable),
        metadata: {
          content_type: share.shareable_type,
          action: share.action
        }
      }
    end
  end

  def member_change_activities(date_from, date_to, user_filter)
    member_changes = department.department_member_histories.includes(:user)
    member_changes = apply_date_filter(member_changes, date_from, date_to)
    member_changes = member_changes.where(user_id: user_filter) if user_filter
    
    member_changes.map do |change|
      {
        id: "member_#{change.id}",
        type: 'member_change',
        title: "Member #{change.action.humanize}: #{change.user.first_name} #{change.user.last_name}",
        description: member_change_description(change),
        user: change.user,
        timestamp: change.created_at,
        icon: member_change_icon(change.action),
        color: member_change_color(change.action),
        url: '/users/' + change.user.id.to_s,
        metadata: {
          action: change.action,
          role: change.user.role,
          previous_role: change.try(:previous_role)
        }
      }
    end
  end

  def assignment_activities(date_from, date_to, user_filter)
    assignments = department.assignments.includes(:user)
    assignments = apply_date_filter(assignments, date_from, date_to)
    assignments = assignments.where(user_id: user_filter) if user_filter
    
    assignments.map do |assignment|
      {
        id: "assignment_#{assignment.id}",
        type: 'assignment',
        title: "New Assignment: #{assignment.title}",
        description: "Due: #{assignment.due_date&.strftime('%B %d, %Y') || 'No due date'}",
        user: assignment.user,
        timestamp: assignment.created_at,
        icon: '📝',
        color: 'purple',
        url: '/assignments/' + assignment.id.to_s,
        metadata: {
          due_date: assignment.due_date,
          published: assignment.try(:published?) || false
        }
      }
    end
  end

  def quiz_activities(date_from, date_to, user_filter)
    quizzes = department.quizzes.includes(:user)
    quizzes = apply_date_filter(quizzes, date_from, date_to)
    quizzes = quizzes.where(user_id: user_filter) if user_filter
    
    quizzes.map do |quiz|
      {
        id: "quiz_#{quiz.id}",
        type: 'quiz',
        title: "New Quiz: #{quiz.title}",
        description: "#{quiz.questions.count} questions available",
        user: quiz.user,
        timestamp: quiz.created_at,
        icon: '❓',
        color: 'yellow',
        url: '/quizzes/' + quiz.id.to_s,
        metadata: {
          questions_count: quiz.questions.count,
          published: quiz.try(:published?) || false
        }
      }
    end
  end

  def note_activities(date_from, date_to, user_filter)
    notes = department.notes.includes(:user)
    notes = apply_date_filter(notes, date_from, date_to)
    notes = notes.where(user_id: user_filter) if user_filter
    
    notes.map do |note|
      {
        id: "note_#{note.id}",
        type: 'note',
        title: "New Note: #{note.title}",
        description: truncate_content(note.content, 150),
        user: note.user,
        timestamp: note.created_at,
        icon: '📋',
        color: 'indigo',
        url: '/notes/' + note.id.to_s,
        metadata: {
          shared: note.try(:shared?) || false
        }
      }
    end
  end

  # Helper methods
  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string) rescue nil
  end

  def parse_activity_types(types_param)
    if types_param.present?
      types_param.is_a?(Array) ? types_param : [types_param]
    else
      # Default to all types if none specified
      ['announcements', 'content_sharing', 'member_changes', 'assignments', 'quizzes', 'notes']
    end
  end

  def apply_date_filter(relation, date_from, date_to)
    return relation unless date_from && date_to
    relation.where(created_at: date_from.beginning_of_day..date_to.end_of_day)
  end

  def truncate_content(content, length)
    return '' if content.blank?
    content.length > length ? "#{content[0...length]}..." : content
  end

  def extract_content_title(content)
    content.try(:title) || content.try(:name) || "Content ##{content.id}"
  end

  def content_type_icon(content_type)
    case content_type
    when 'Assignment' then '📝'
    when 'Quiz' then '❓'
    when 'Note' then '📋'
    else '📄'
    end
  end

  def content_url(content)
    return '#' unless content
    
    begin
      case content.class.name
      when 'Assignment'
        '/assignments/' + content.id.to_s
      when 'Quiz'
        '/quizzes/' + content.id.to_s
      when 'Note'
        '/notes/' + content.id.to_s
      else
        '#'
      end
    rescue
      '#'
    end
  end

  def member_change_description(change)
    case change.action
    when 'joined'
      "#{change.user.first_name} #{change.user.last_name} joined the department as #{change.user.role}"
    when 'left'
      "#{change.user.first_name} #{change.user.last_name} left the department"
    when 'role_changed'
      previous_role = change.try(:previous_role) || 'member'
      "#{change.user.first_name} #{change.user.last_name}'s role changed from #{previous_role} to #{change.user.role}"
    when 'status_changed'
      "#{change.user.first_name} #{change.user.last_name}'s status was updated"
    else
      "Member information updated for #{change.user.first_name} #{change.user.last_name}"
    end
  end

  def member_change_icon(action)
    case action
    when 'joined' then '➕'
    when 'left' then '➖'
    when 'role_changed' then '🔄'
    when 'status_changed' then '📝'
    else '👥'
    end
  end

  def member_change_color(action)
    case action
    when 'joined' then 'green'
    when 'left' then 'red'
    when 'role_changed' then 'blue'
    when 'status_changed' then 'yellow'
    else 'gray'
    end
  end
end