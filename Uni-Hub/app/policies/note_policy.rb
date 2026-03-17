# Policy for Note model
# Controls who can view, create, update notes based on ownership and department access
class NotePolicy < ApplicationPolicy
  # Users can view index if they're authenticated
  def index?
    true
  end

  # Users can view notes they own, have been shared with, or are in accessible departments
  def show?
    return true if admin?
    return true if owner?
    return true if record.viewable_by?(user)
    
    # Check department access
    can_access_department?(record.department)
  end

  # All authenticated users can create notes
  def create?
    true
  end

  # Users can update their own notes or notes shared with edit permission
  def update?
    return true if admin?
    return true if owner?
    record.editable_by?(user)
  end

  # Users can destroy only their own notes
  def destroy?
    admin? || owner?
  end

  # Only owner can share their notes
  def share?
    admin? || owner?
  end

  # Anyone who can view can export
  def export?
    show?
  end

  # Anyone who can edit can auto-save
  def auto_save?
    update?
  end

  # Scope: Filter notes based on ownership, sharing, and department access
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.super_admin?
        # Admins see all notes
        scope.all
      else
        # Users see:
        # 1. Their own notes
        # 2. Notes shared with them
        # 3. Notes in departments they have access to (if tutor/teacher)
        owned_notes = scope.where(user: user)
        shared_note_ids = NoteShare.where(shared_with: user).pluck(:note_id)
        shared_notes = scope.where(id: shared_note_ids)
        
        if user.tutor? || user.teacher?
          # Include notes from accessible departments
          dept_ids = user.all_departments.pluck(:id)
          dept_notes = scope.where(department_id: dept_ids)
          scope.where(id: owned_notes.pluck(:id) + shared_notes.pluck(:id) + dept_notes.pluck(:id)).distinct
        elsif user.student?
          # Students see own notes, shared notes, and notes in their department
          dept_notes = scope.where(department_id: user.department_id)
          scope.where(id: owned_notes.pluck(:id) + shared_notes.pluck(:id) + dept_notes.pluck(:id)).distinct
        else
          # Default: own + shared notes only
          scope.where(id: owned_notes.pluck(:id) + shared_notes.pluck(:id)).distinct
        end
      end
    end
  end
end
