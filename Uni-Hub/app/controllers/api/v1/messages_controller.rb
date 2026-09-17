module Api
  module V1
    class MessagesController < BaseController
      before_action :set_recipient, only: [:create]
      before_action :set_conversation_partner, only: [:show, :mark_as_read]

      def conversations
        threads = ChatMessage.conversation_threads_for(current_user)
        render_success(threads.map { |t| serialize_thread(t) })
      end

      def show
        messages = ChatMessage.between_users(current_user, @conversation_partner)
                              .includes(:sender, :recipient)
                              .order(:created_at)
        messages.where(recipient: current_user, read_at: nil).update_all(read_at: Time.current)

        render_success(messages.map { |m| serialize_message(m) })
      end

      def create
        message = current_user.sent_messages.build(content: chat_message_params[:content])
        message.recipient = @recipient
        message.message_type = chat_message_params[:message_type].presence || "text"

        if message.save
          render_success(serialize_message(message), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: message.errors.messages
          )
        end
      end

      def mark_as_read
        current_user.received_messages
                    .where(sender: @conversation_partner, read_at: nil)
                    .update_all(read_at: Time.current)
        render_message("Messages marked as read")
      end

      def search_users
        query = params[:q].to_s.strip
        users = if query.present?
                  User.where.not(id: current_user.id)
                      .where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
                             "%#{query}%", "%#{query}%", "%#{query}%")
                      .limit(10)
                else
                  []
                end
        render_success(users.map { |u| { id: u.id, name: u.full_name, email: u.email, department: u.department&.name } })
      end

      private

      def set_recipient
        @recipient = User.find_by(id: chat_message_params[:recipient_id])
        render_error("Recipient not found", status: :not_found, code: "NOT_FOUND") if @recipient.nil?
      end

      def set_conversation_partner
        @conversation_partner = User.find(params[:id])
      end

      def chat_message_params
        params.require(:message).permit(:content, :recipient_id, :message_type)
      end

      def serialize_thread(thread)
        partner = thread[:partner]
        last_message = thread[:last_message]
        {
          id: last_message&.id || partner.id,
          user: { id: partner.id, name: partner.full_name },
          last_message: last_message&.content,
          last_message_at: last_message&.created_at,
          unread_count: thread[:unread_count]
        }
      end

      def serialize_message(message)
        {
          id: message.id,
          sender_id: message.sender_id,
          recipient_id: message.recipient_id,
          content: message.content,
          read: message.read?,
          sender_name: message.sender&.full_name,
          recipient_name: message.recipient&.full_name,
          created_at: message.created_at
        }
      end
    end
  end
end