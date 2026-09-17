module Api
  module V1
    class NotificationsController < BaseController
      before_action :set_notification, only: [:mark_as_read]

      def index
        notifications = current_user.notifications.recent.limit(50)
        render_success(notifications.map { |n| serialize_notification(n) })
      end

      def unread_count
        render_success({ count: current_user.unread_notifications_count })
      end

      def mark_as_read
        @notification.mark_as_read!
        render_success(serialize_notification(@notification))
      end

      def mark_all_as_read
        current_user.notifications.unread.update_all(read: true)
        render_message("All notifications marked as read")
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end

      def serialize_notification(notification)
        {
          id: notification.id,
          title: notification.title,
          body: notification.message,
          notification_type: notification.notification_type,
          read: notification.read,
          action_url: notification.action_url,
          created_at: notification.created_at
        }
      end
    end
  end
end