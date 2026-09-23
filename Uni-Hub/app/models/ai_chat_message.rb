class AiChatMessage < ApplicationRecord
  belongs_to :user

  ROLES = %w[user assistant system].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :for_user, ->(user) { where(user: user) }
  scope :chronological, -> { order(:created_at) }
  scope :recent, ->(limit = 40) { chronological.last(limit) }

  # Trims the conversation to the most recent N messages after each turn,
  # keeping the memory bounded so prompts stay within model context limits.
  MAX_HISTORY_MESSAGES = 40

  def self.conversation_for(user, limit: MAX_HISTORY_MESSAGES)
    for_user(user).chronological.where(role: %w[user assistant]).last(limit)
  end

  def self.record!(user, role:, content:, **attrs)
    create!(user: user, role: role, content: content, **attrs)
  end

  def self.clear_for!(user)
    for_user(user).delete_all
  end
end