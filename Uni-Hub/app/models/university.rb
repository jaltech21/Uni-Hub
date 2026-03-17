class University < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :users, through: :departments
  
  validates :name, presence: true, length: { maximum: 200 }
  validates :code, presence: true, length: { maximum: 20 }, uniqueness: { case_sensitive: false }
  
  scope :active, -> { where(active: true) }
  
  before_validation :normalize_code
  
  private
  
  def normalize_code
    self.code = code.to_s.upcase.strip if code.present?
  end
end