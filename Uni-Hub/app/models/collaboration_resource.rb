class CollaborationResource < ApplicationRecord
  belongs_to :cross_campus_collaboration
  
  validates :resource_type, presence: true,
            inclusion: { in: %w[document dataset equipment facility software license funding] }
  validates :name, presence: true, length: { maximum: 255 }
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true
  
  scope :by_type, ->(type) { where(resource_type: type) }
  scope :documents, -> { where(resource_type: 'document') }
  scope :datasets, -> { where(resource_type: 'dataset') }
  scope :equipment, -> { where(resource_type: 'equipment') }
  scope :facilities, -> { where(resource_type: 'facility') }
  
  def external_resource?
    url.present?
  end
end