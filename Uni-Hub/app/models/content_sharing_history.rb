class ContentSharingHistory < ApplicationRecord
  belongs_to :shareable, polymorphic: true
  belongs_to :department
  belongs_to :shared_by, class_name: 'User'
  
  validates :action, presence: true, inclusion: { in: %w[shared unshared permission_changed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_shareable, ->(shareable) { where(shareable: shareable) }
  scope :for_department, ->(department_id) { where(department_id: department_id) }
  
  ACTIONS = %w[shared unshared permission_changed].freeze
end
