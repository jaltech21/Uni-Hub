class Tag < ApplicationRecord
  has_many :note_tags, dependent: :destroy
  has_many :notes, through: :note_tags
  
  validates :name, presence: true, uniqueness: true, length: { minimum: 1, maximum: 30 }
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i, message: "must be a valid hex color" }, allow_blank: true
  
  scope :popular, -> { joins(:note_tags).group(:id).order('COUNT(note_tags.id) DESC') }
  scope :alphabetical, -> { order(:name) }
  
  # Normalize tag name before save
  before_validation :normalize_name
  
  # Find or create tag by name
  def self.find_or_create_by_name(name)
    normalized = name.to_s.strip.downcase
    find_or_create_by(name: normalized)
  end
  
  # Count notes with this tag
  def notes_count
    notes.count
  end
  
  private
  
  def normalize_name
    self.name = name.to_s.strip.downcase if name.present?
  end
end
