class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:mark_as_read, :destroy]
  
  # GET /notifications
  def index
    @notifications = current_user.notifications.recent.limit(50)
    @unread_count = current_user.unread_notifications_count
    
    respond_to do |format|
      format.html
      format.json { render json: @notifications }
    end
  end
  
  # GET /notifications/unread_count
  def unread_count
    render json: { count: current_user.unread_notifications_count }
  end
  
  # PATCH /notifications/:id/mark_as_read
  def mark_as_read
    @notification.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: notifications_path, notice: 'Notification marked as read.') }
      format.json { render json: { success: true, notification: @notification } }
    end
  end
  
  # PATCH /notifications/mark_all_as_read
  def mark_all_as_read
    current_user.notifications.unread.update_all(read: true)
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'All notifications marked as read.' }
      format.json { render json: { success: true, message: 'All notifications marked as read' } }
    end
  end
  
  # DELETE /notifications/:id
  def destroy
    @notification.destroy
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'Notification deleted.' }
      format.json { head :no_content }
    end
  end
  
  # GET /notifications/recent
  def recent
    @notifications = current_user.notifications.recent.limit(10)
    render json: @notifications.map { |n| notification_json(n) }
  end
  
  private
  
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
  
  def notification_json(notification)
    {
      id: notification.id,
      title: notification.title,
      message: notification.message,
      notification_type: notification.notification_type,
      read: notification.read,
      action_url: notification.action_url,
      icon: notification.icon,
      color: notification.color,
      time_ago: notification.time_ago,
      created_at: notification.created_at
    }
  end
end
