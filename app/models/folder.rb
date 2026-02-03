class Folder < ApplicationRecord
  belongs_to :user
  has_many :notes, dependent: :nullify
  
  validates :name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :name, uniqueness: { scope: :user_id, message: "already exists" }
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i, message: "must be a valid hex color" }, allow_blank: true
  
  scope :ordered, -> { order(:position, :created_at) }
  scope :by_user, ->(user) { where(user: user) }
  
  # Count notes in this folder
  def notes_count
    notes.count
  end
  
  # Get recent notes
  def recent_notes(limit = 5)
    notes.order(updated_at: :desc).limit(limit)
  end
end
