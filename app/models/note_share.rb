class NoteShare < ApplicationRecord
  belongs_to :note
  belongs_to :shared_by, class_name: 'User', foreign_key: 'shared_by_id'
  belongs_to :shared_with, class_name: 'User', foreign_key: 'shared_with_id'
  
  validates :permission, inclusion: { in: %w[view edit], message: "must be 'view' or 'edit'" }
  validates :shared_with_id, uniqueness: { scope: :note_id, message: "already has access to this note" }
  validate :cannot_share_with_self
  validate :cannot_share_with_owner
  
  scope :by_user, ->(user) { where(shared_with: user) }
  scope :view_only, -> { where(permission: 'view') }
  scope :editable, -> { where(permission: 'edit') }
  
  # Check if user can edit
  def can_edit?
    permission == 'edit'
  end
  
  # Check if user can only view
  def can_only_view?
    permission == 'view'
  end
  
  private
  
  def cannot_share_with_self
    if shared_by_id == shared_with_id
      errors.add(:shared_with, "cannot share note with yourself")
    end
  end
  
  def cannot_share_with_owner
    if note.user_id == shared_with_id
      errors.add(:shared_with, "is already the owner of this note")
    end
  end
end
