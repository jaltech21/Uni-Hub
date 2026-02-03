# Policy for User model
# Controls who can view, update users and manage roles/departments
class UserPolicy < ApplicationPolicy
  # Only admins can view user index
  def index?
    admin?
  end

  # Users can view their own profile, admins can view all
  def show?
    admin? || record == user
  end

  # Users can update their own profile, admins can update all
  def update?
    admin? || record == user
  end

  # Only admins can destroy users
  def destroy?
    admin? && record != user # Can't delete yourself
  end

  # Only admins can assign departments
  def assign_department?
    admin?
  end

  # Only admins can change roles
  def change_role?
    admin?
  end

  # Only admins can manage teaching departments
  def manage_teaching_departments?
    admin?
  end

  # Scope: Filter users based on role
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins see all users
        scope.all
      elsif user.tutor? || user.teacher?
        # Teachers see students in their departments
        dept_ids = user.all_departments.pluck(:id)
        scope.where(department_id: dept_ids)
      else
        # Students only see themselves
        scope.where(id: user.id)
      end
    end
  end
end
