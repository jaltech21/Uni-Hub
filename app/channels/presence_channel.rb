class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'presence_channel'
    
    # Mark user as online
    update_user_presence(true)
    
    # Broadcast user came online
    broadcast_presence_update(true)
    
    Rails.logger.info "PresenceChannel: User #{current_user.id} came online"
  end

  def unsubscribed
    # Mark user as offline
    update_user_presence(false)
    
    # Broadcast user went offline
    broadcast_presence_update(false)
    
    Rails.logger.info "PresenceChannel: User #{current_user.id} went offline"
  end
  
  def heartbeat
    # Update last seen timestamp
    update_user_presence(true)
  end
  
  def get_online_users
    # Send list of currently online users
    online_users = get_online_users_list
    
    transmit({
      type: 'online_users_list',
      users: online_users
    })
  end

  private

  def update_user_presence(online)
    presence_data = {
      online: online,
      last_seen: Time.current.iso8601,
      user_id: current_user.id
    }
    
    # Store in Rails cache (use Redis in production for persistence)
    Rails.cache.write("user_presence_#{current_user.id}", presence_data, expires_in: 5.minutes)
    
    # Also store in a global online users set
    if online
      online_users = Rails.cache.read('online_users') || Set.new
      online_users.add(current_user.id)
      Rails.cache.write('online_users', online_users, expires_in: 10.minutes)
    else
      online_users = Rails.cache.read('online_users') || Set.new
      online_users.delete(current_user.id)
      Rails.cache.write('online_users', online_users, expires_in: 10.minutes)
    end
  end

  def broadcast_presence_update(online)
    ActionCable.server.broadcast('presence_channel', {
      type: 'presence_update',
      user: {
        id: current_user.id,
        name: current_user.full_name,
        email: current_user.email
      },
      online: online,
      last_seen: Time.current.iso8601
    })
  end
  
  def get_online_users_list
    online_user_ids = Rails.cache.read('online_users') || Set.new
    
    User.where(id: online_user_ids.to_a).limit(100).map do |user|
      presence_data = Rails.cache.read("user_presence_#{user.id}")
      {
        id: user.id,
        name: user.full_name,
        email: user.email,
        last_seen: presence_data&.dig(:last_seen) || Time.current.iso8601
      }
    end
  end
end
