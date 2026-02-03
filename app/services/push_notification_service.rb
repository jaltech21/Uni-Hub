# app/services/push_notification_service.rb
class PushNotificationService
  include HTTParty
  
  # In a real application, you would use services like:
  # - Firebase Cloud Messaging (FCM)
  # - Apple Push Notification Service (APNs)
  # - Web Push Protocol
  
  def self.send_message_notification(user, sender, message)
    return unless user.push_subscription.present?
    
    payload = {
      title: "New message from #{sender.name}",
      message: truncate_message(message.content),
      icon: '/icon.png',
      badge: '/icon.png',
      url: '/messages/conversations',
      tag: "message-#{sender.id}",
      data: {
        message_id: message.id,
        sender_id: sender.id,
        sender_name: sender.name,
        conversation_url: "/messages/#{sender.id}"
      }
    }
    
    send_push_notification(user.push_subscription, payload)
  end
  
  def self.send_announcement_notification(users, announcement)
    users.find_each do |user|
      next unless user.push_subscription.present?
      
      payload = {
        title: "New Announcement",
        message: truncate_message(announcement.title),
        icon: '/icon.png',
        badge: '/icon.png',
        url: "/announcements/#{announcement.id}",
        tag: "announcement-#{announcement.id}",
        data: {
          announcement_id: announcement.id,
          announcement_url: "/announcements/#{announcement.id}"
        }
      }
      
      send_push_notification(user.push_subscription, payload)
    end
  end
  
  def self.send_assignment_reminder(user, assignment)
    return unless user.push_subscription.present?
    
    payload = {
      title: "Assignment Due Soon",
      message: "#{assignment.title} is due #{time_until_due(assignment.due_date)}",
      icon: '/icon.png',
      badge: '/icon.png',
      url: "/assignments/#{assignment.id}",
      tag: "assignment-#{assignment.id}",
      data: {
        assignment_id: assignment.id,
        assignment_url: "/assignments/#{assignment.id}"
      }
    }
    
    send_push_notification(user.push_subscription, payload)
  end
  
  private
  
  def self.send_push_notification(subscription_data, payload)
    # This is a simplified version - in production you would use:
    # - webpush gem for Web Push Protocol
    # - fcm gem for Firebase Cloud Messaging
    # - apnotic gem for Apple Push Notifications
    
    Rails.logger.info "Sending push notification: #{payload[:title]}"
    Rails.logger.info "To subscription: #{subscription_data['endpoint'][0..50]}..."
    
    # Example using webpush gem (you would need to add it to Gemfile):
    # begin
    #   Webpush.payload_send(
    #     message: payload.to_json,
    #     endpoint: subscription_data['endpoint'],
    #     p256dh: subscription_data['keys']['p256dh'],
    #     auth: subscription_data['keys']['auth'],
    #     vapid: {
    #       subject: Rails.application.credentials.vapid_subject,
    #       public_key: Rails.application.credentials.vapid_public_key,
    #       private_key: Rails.application.credentials.vapid_private_key
    #     }
    #   )
    #   Rails.logger.info "Push notification sent successfully"
    # rescue => e
    #   Rails.logger.error "Failed to send push notification: #{e.message}"
    # end
    
    # For now, we'll just log the notification
    Rails.logger.info "Push notification payload: #{payload.to_json}"
    true
  end
  
  def self.truncate_message(text, length = 50)
    return text if text.length <= length
    "#{text[0..length-4]}..."
  end
  
  def self.time_until_due(due_date)
    return "today" if due_date.to_date == Date.current
    return "tomorrow" if due_date.to_date == Date.current + 1.day
    
    days_until = (due_date.to_date - Date.current).to_i
    return "in #{days_until} days" if days_until > 0
    
    "overdue"
  end
end