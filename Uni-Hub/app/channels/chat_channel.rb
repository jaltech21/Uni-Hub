class ChatChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to user's personal channel for direct messages
    stream_from "chat_#{current_user.id}"
    
    # Subscribe to conversations the user is part of
    conversation_ids = ChatMessage.where("sender_id = ? OR recipient_id = ?", current_user.id, current_user.id)
                                 .distinct
                                 .pluck("CASE WHEN sender_id = #{current_user.id} THEN recipient_id ELSE sender_id END")
    
    conversation_ids.each do |other_user_id|
      conversation_key = [current_user.id, other_user_id].sort.join('_')
      stream_from "conversation_#{conversation_key}"
    end
    
    # Update user's online status
    update_presence(true)
    
    Rails.logger.info "ChatChannel: User #{current_user.id} subscribed"
  end

  def unsubscribed
    # Update user's offline status
    update_presence(false)
    
    Rails.logger.info "ChatChannel: User #{current_user.id} unsubscribed"
  end

  def speak(data)
    recipient = User.find(data['recipient_id'])
    message_content = data['message']
    
    # Create the message in the database
    message = current_user.send_message_to(recipient, message_content)
    
    # Create conversation key for this pair of users
    conversation_key = [current_user.id, recipient.id].sort.join('_')
    
    # Broadcast to both users
    ActionCable.server.broadcast("chat_#{conversation_key}", {
      type: 'new_message',
      message: {
        id: message.id,
        content: message_content,
        created_at: message.created_at
      },
      sender: {
        id: current_user.id,
        name: current_user.name
      },
      conversation_key: conversation_key
    })
    
    # Also broadcast a notification specifically to the recipient
    ActionCable.server.broadcast("notifications_#{recipient.id}", {
      type: 'message_notification',
      message: {
        id: message.id,
        content: message_content,
        created_at: message.created_at
      },
      sender: {
        id: current_user.id,
        name: current_user.name
      }
    })
    
    # Send push notification if recipient wants them and is not currently active
    if recipient.wants_notification?('messages') && recipient.has_push_subscription?
      PushNotificationService.send_message_notification(recipient, current_user, message)
    end
  end
  
  def typing(data)
    recipient_id = data['recipient_id']
    is_typing = data['is_typing']
    
    return unless recipient_id
    
    conversation_key = [current_user.id, recipient_id.to_i].sort.join('_')
    
    # Broadcast typing status to conversation
    ActionCable.server.broadcast("conversation_#{conversation_key}", {
      type: 'typing_status',
      user: format_user(current_user),
      is_typing: is_typing,
      conversation_key: conversation_key
    })
  end
  
  def mark_as_read(data)
    message_ids = data['message_ids']
    
    return unless message_ids.present?
    
    # Mark messages as read
    ChatMessage.where(id: message_ids, recipient: current_user)
               .where(read_at: nil)
               .update_all(read_at: Time.current)
    
    # Broadcast read status to senders
    messages = ChatMessage.where(id: message_ids).includes(:sender)
    messages.group_by(&:sender_id).each do |sender_id, msgs|
      conversation_key = [current_user.id, sender_id].sort.join('_')
      
      ActionCable.server.broadcast("conversation_#{conversation_key}", {
        type: 'messages_read',
        message_ids: msgs.map(&:id),
        reader: format_user(current_user),
        conversation_key: conversation_key
      })
    end
  end
  
  def subscribe_to_conversation(data)
    recipient_id = data['recipient_id']
    return unless recipient_id
    
    conversation_key = [current_user.id, recipient_id.to_i].sort.join('_')
    stream_from "conversation_#{conversation_key}"
    
    Rails.logger.info "ChatChannel: User #{current_user.id} subscribed to conversation with #{recipient_id}"
  end
  
  private
  
  def update_presence(online)
    # Store presence in Rails cache (in production, use Redis)
    Rails.cache.write("user_presence_#{current_user.id}", {
      online: online,
      last_seen: Time.current
    }, expires_in: 5.minutes)
    
    # Broadcast presence update to all connected users
    ActionCable.server.broadcast('presence_channel', {
      type: 'presence_update',
      user: format_user(current_user),
      online: online,
      last_seen: Time.current.iso8601
    })
  end
  
  def format_message(message)
    {
      id: message.id,
      content: message.content,
      created_at: message.created_at.iso8601,
      read_at: message.read_at&.iso8601,
      sender_id: message.sender_id,
      recipient_id: message.recipient_id,
      conversation_id: message.conversation_id
    }
  end
  
  def format_user(user)
    {
      id: user.id,
      name: user.full_name,
      email: user.email,
      avatar_url: nil # Add avatar support later
    }
  end
end
