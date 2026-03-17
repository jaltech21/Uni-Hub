class ChatMessage < ApplicationRecord
  belongs_to :sender, class_name: 'User'
  belongs_to :recipient, class_name: 'User'
  
  # Validations
  validates :content, presence: true, length: { maximum: 1000 }
  validates :message_type, presence: true, inclusion: { in: %w[text image file system] }
  validates :sender_id, presence: true
  validates :recipient_id, presence: true
  
  # Scopes
  scope :between_users, ->(user1, user2) { 
    where(
      "(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)",
      user1.id, user2.id, user2.id, user1.id
    ).order(:created_at)
  }
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_thread, ->(thread_id) { where(thread_id: thread_id) }
  
  # Instance methods
  def read?
    read_at.present?
  end
  
  def unread?
    read_at.nil?
  end
  
  def mark_as_read!
    update(read_at: Time.current) unless read?
  end
  
  def conversation_partner(current_user)
    sender == current_user ? recipient : sender
  end
  
  def self.conversation_threads_for(user)
    # Get all unique conversation partners
    sent_to = where(sender: user).distinct.pluck(:recipient_id)
    received_from = where(recipient: user).distinct.pluck(:sender_id)
    partner_ids = (sent_to + received_from).uniq
    
    threads = []
    partner_ids.each do |partner_id|
      partner = User.find(partner_id)
      last_message = between_users(user, partner).last
      unread_count = where(sender: partner, recipient: user, read_at: nil).count
      
      threads << {
        partner: partner,
        last_message: last_message,
        unread_count: unread_count,
        updated_at: last_message&.created_at || Time.current
      }
    end
    
    threads.sort_by { |thread| thread[:updated_at] }.reverse
  end
end
