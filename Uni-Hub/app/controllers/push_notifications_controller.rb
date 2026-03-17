# app/controllers/push_notifications_controller.rb
class PushNotificationsController < ApplicationController
  before_action :authenticate_user!
  
  # Show notification settings page
  def index
    # This will render the index.html.erb view
  end
  
  # Subscribe to push notifications
  def subscribe
    subscription_data = params.require(:subscription).permit(
      :endpoint,
      keys: [:p256dh, :auth]
    )
    
    if current_user.update_push_subscription(subscription_data.to_h)
      render json: { 
        status: 'success', 
        message: 'Push notifications enabled successfully' 
      }
    else
      render json: { 
        status: 'error', 
        message: 'Failed to enable push notifications' 
      }, status: :unprocessable_entity
    end
  end
  
  # Unsubscribe from push notifications
  def unsubscribe
    current_user.clear_push_subscription
    render json: { 
      status: 'success', 
      message: 'Push notifications disabled successfully' 
    }
  end
  
  # Get current subscription status
  def status
    render json: {
      subscribed: current_user.has_push_subscription?,
      preferences: current_user.notification_preferences
    }
  end
  
  # Update notification preferences
  def update_preferences
    preferences = params.require(:preferences).permit(
      enabled: [:messages, :announcements, :assignments, :reminders, :discussions],
      sound: [],
      vibrate: []
    )
    
    current_prefs = current_user.notification_preferences
    updated_prefs = current_prefs.merge(preferences.to_h)
    
    if current_user.update!(notification_preferences: updated_prefs)
      render json: { 
        status: 'success', 
        message: 'Notification preferences updated',
        preferences: updated_prefs
      }
    else
      render json: { 
        status: 'error', 
        message: 'Failed to update preferences' 
      }, status: :unprocessable_entity
    end
  end
  
  # Test notification (for development/testing)
  def test
    if Rails.env.development?
      PushNotificationService.send_message_notification(
        current_user,
        current_user,
        OpenStruct.new(content: "This is a test notification! 🎉")
      )
      
      render json: { 
        status: 'success', 
        message: 'Test notification sent (check logs)' 
      }
    else
      render json: { 
        status: 'error', 
        message: 'Test notifications only available in development' 
      }, status: :forbidden
    end
  end
  
  private
  
  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end