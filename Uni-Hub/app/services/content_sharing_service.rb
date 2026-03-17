# Service to handle cross-department content sharing
class ContentSharingService
  attr_reader :content, :user
  
  def initialize(content, user)
    @content = content
    @user = user
  end
  
  # Share content with departments
  def share_with_departments(department_ids, permission_level: 'view')
    results = { success: [], failed: [] }
    
    department_ids.each do |dept_id|
      department = Department.find_by(id: dept_id)
      next unless department
      
      begin
        sharing = create_sharing_record(department, permission_level)
        if sharing.persisted?
          log_sharing_history(department, 'shared', permission_level)
          results[:success] << department
        else
          results[:failed] << { department: department, errors: sharing.errors.full_messages }
        end
      rescue => e
        results[:failed] << { department: department, errors: [e.message] }
      end
    end
    
    results
  end
  
  # Unshare content from departments
  def unshare_from_departments(department_ids)
    results = { success: [], failed: [] }
    
    department_ids.each do |dept_id|
      department = Department.find_by(id: dept_id)
      next unless department
      
      begin
        if remove_sharing_record(department)
          log_sharing_history(department, 'unshared')
          results[:success] << department
        else
          results[:failed] << { department: department, errors: ['Failed to remove sharing'] }
        end
      rescue => e
        results[:failed] << { department: department, errors: [e.message] }
      end
    end
    
    results
  end
  
  # Update permission level for shared departments
  def update_permission(department_id, new_permission_level)
    department = Department.find_by(id: department_id)
    return false unless department
    
    sharing = get_sharing_record(department)
    return false unless sharing
    
    if sharing.update(permission_level: new_permission_level)
      log_sharing_history(department, 'permission_changed', new_permission_level)
      true
    else
      false
    end
  end
  
  # Get all departments this content is shared with
  def shared_departments
    case content
    when Assignment
      content.additional_departments
    when Note
      content.shared_departments
    when Quiz
      content.shared_departments
    else
      []
    end
  end
  
  # Get sharing history for this content
  def sharing_history
    content.content_sharing_histories.includes(:department, :shared_by).recent
  end
  
  # Check if content is shared with a specific department
  def shared_with?(department)
    shared_departments.include?(department)
  end
  
  # Get permission level for a specific department
  def permission_for(department)
    sharing = get_sharing_record(department)
    sharing&.permission_level
  end
  
  private
  
  def create_sharing_record(department, permission_level)
    case content
    when Assignment
      content.assignment_departments.create(
        department: department,
        shared_by: user,
        permission_level: permission_level
      )
    when Note
      content.note_departments.create(
        department: department,
        shared_by: user,
        permission_level: permission_level
      )
    when Quiz
      content.quiz_departments.create(
        department: department,
        shared_by: user,
        permission_level: permission_level
      )
    end
  end
  
  def remove_sharing_record(department)
    case content
    when Assignment
      content.assignment_departments.where(department: department).destroy_all
    when Note
      content.note_departments.where(department: department).destroy_all
    when Quiz
      content.quiz_departments.where(department: department).destroy_all
    end
  end
  
  def get_sharing_record(department)
    case content
    when Assignment
      content.assignment_departments.find_by(department: department)
    when Note
      content.note_departments.find_by(department: department)
    when Quiz
      content.quiz_departments.find_by(department: department)
    end
  end
  
  def log_sharing_history(department, action, permission_level = nil)
    content.content_sharing_histories.create(
      department: department,
      shared_by: user,
      action: action,
      permission_level: permission_level
    )
  end
end
