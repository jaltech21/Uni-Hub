class AnnouncementPolicy < ApplicationPolicy
  def index?
    # Everyone can view announcements for their department
    can_access_department?(record.first&.department) if record.respond_to?(:first)
    true
  end
  
  def show?
    # Users can view announcements if they have access to the department
    can_access_department?(record.department)
  end
  
  def create?
    # Teachers, tutors, and admins can create announcements
    user.teacher? || user.tutor? || admin?
  end
  
  def new?
    create?
  end
  
  def update?
    # Only the creator or admins can update
    owner? || admin?
  end
  
  def edit?
    update?
  end
  
  def destroy?
    # Only the creator or admins can delete
    owner? || admin?
  end
  
  def publish?
    # Only the creator or admins can publish
    owner? || admin?
  end
  
  def unpublish?
    publish?
  end
  
  def toggle_pin?
    # Only admins and teachers can pin announcements
    (user.teacher? && can_access_department?(record.department)) || admin?
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins can see all announcements
        scope.all
      elsif user.teacher? || user.tutor?
        # Teachers/tutors see announcements for their departments
        department_ids = user.teaching_departments.pluck(:id)
        department_ids << user.department_id if user.department_id
        scope.where(department_id: department_ids.compact.uniq)
      else
        # Students see published announcements for their department
        scope.published.active.where(department_id: user.department_id)
      end
    end
  end
end
