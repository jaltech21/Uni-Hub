# Policy for Department model
# Controls who can view, create, update departments
class DepartmentPolicy < ApplicationPolicy
  # Anyone can view the index (filtered by Scope)
  def index?
    true
  end

  # Users can view departments they have access to
  def show?
    can_access_department?(record)
  end

  # Only admins can create departments
  def create?
    admin?
  end

  # Only admins can update departments
  def update?
    admin?
  end

  # Only admins can destroy departments
  def destroy?
    admin?
  end

  # Only admins can toggle active status
  def toggle_active?
    admin?
  end

  # Scope: Filter departments based on user role
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins see all departments
        scope.all
      elsif user.tutor? || user.teacher?
        # Tutors see departments they teach in
        scope.where(id: user.teaching_departments.pluck(:id))
      elsif user.student?
        # Students see only their department
        scope.where(id: user.department_id)
      else
        # Default: no departments
        scope.none
      end
    end
  end
end
