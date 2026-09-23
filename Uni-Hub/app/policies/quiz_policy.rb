# Policy for Quiz model
# Controls who can view, create, update quizzes based on ownership and department access
class QuizPolicy < ApplicationPolicy
  # Users can view index if they're authenticated
  def index?
    true
  end

  # Users can view quizzes they own or are in accessible departments
  def show?
    return true if admin?
    return true if owner?
    
    # Check if quiz is published and in accessible department
    return false unless record.published?
    can_access_department?(record.department)
  end

  # All authenticated users can create quizzes
  def create?
    true
  end

  # Only the owner or admin can update
  def update?
    admin? || owner?
  end

  # Only the owner or admin can destroy
  def destroy?
    admin? || owner?
  end

  # Only the owner can publish
  def publish?
    admin? || owner?
  end

  # Anyone can take a published quiz in their accessible departments
  def take?
    return true if admin?
    return true if owner?
    
    # Must be published and in accessible department
    record.published? && can_access_department?(record.department)
  end

  # Anyone who can take can submit
  def submit_quiz?
    take?
  end

  # Anyone who has taken the quiz can view results
  def results?
    return true if admin?
    return true if owner?
    
    # Check if user has an attempt for this quiz
    record.quiz_attempts.exists?(user: user)
  end

  # Any authenticated user can generate a quiz from their own notes.
  # The record passed to #generate / #generate_from_note is the Quiz class,
  # so owner? (which reads record.user) is never true for it. Generation is
  # always scoped to current_user.notes in the controller, so it is safe to
  # grant to any signed-in user.
  def generate?
    true
  end

  def generate_from_note?
    true
  end

  # Scope: Filter quizzes based on ownership and department access
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins see all quizzes
        scope.all
      elsif user.tutor? || user.teacher?
        # Teachers/Tutors see:
        # 1. Their own quizzes
        # 2. Published quizzes in departments they teach
        dept_ids = user.all_departments.pluck(:id)
        scope.where(user: user)
             .or(scope.where(status: 'published', department_id: dept_ids))
             .distinct
      elsif user.student?
        # Students see:
        # 1. Their own quizzes
        # 2. Published quizzes in their department
        scope.where(user: user)
             .or(scope.where(status: 'published', department_id: user.department_id))
             .distinct
      else
        # Default: only own quizzes
        scope.where(user: user)
      end
    end
  end
end
