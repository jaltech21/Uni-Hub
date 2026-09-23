# Policy for Assignment model
# Controls who can view, create, update assignments based on department access
class AssignmentPolicy < ApplicationPolicy
  # Users can view index if they're authenticated
  def index?
    true
  end

  # Users can view assignments in departments they have access to
  def show?
    return true if admin?
    return true if owner?

    # Students can only view assignments for courses they are actively enrolled in
    return record.visible_to?(user) if user.student?

    # Teachers/Tutors can access assignments in departments they teach
    record.all_departments.any? { |dept| can_access_department?(dept) }
  end

  # Only teachers, tutors, and admins can create assignments
  def create?
    admin? || user.teacher? || user.tutor?
  end

  # Only the owner or admin can update
  def update?
    admin? || owner?
  end

  # Only the owner or admin can destroy
  def destroy?
    admin? || owner?
  end

  # Scope: Filter assignments based on user's accessible departments
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins see all assignments
        scope.all
      elsif user.teacher? || user.tutor?
        # Teachers/Tutors see:
        # 1. Their own assignments
        # 2. Assignments in departments they teach
        dept_ids = user.all_departments.pluck(:id)
        scope.left_joins(:assignment_departments)
             .where("assignments.user_id = ? OR assignments.department_id IN (?) OR assignment_departments.department_id IN (?)", 
                    user.id, dept_ids, dept_ids)
             .distinct
      elsif user.student?
        # Students only see assignments for schedules they are enrolled in
        return scope.none if user.department_id.nil?

        scope.where(id: Assignment.visible_to_student(user).select(:id)).distinct
      else
        # Default: no assignments
        scope.none
      end
    end
  end
end
