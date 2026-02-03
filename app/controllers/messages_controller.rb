class MessagesController < ApplicationController
  layout 'dashboard'
  before_action :authenticate_user!
  before_action :set_message, only: [:destroy]
  before_action :set_conversation_partner, only: [:show, :create]
  
  def index
    redirect_to conversations_messages_path
  end

  def conversations
    @conversation_threads = ChatMessage.conversation_threads_for(current_user)
    @users = User.where.not(id: current_user.id).includes(:department)
                 .order(:email)
                 .limit(20)
  end

  def show
    @messages = ChatMessage.between_users(current_user, @conversation_partner)
                          .includes(:sender, :recipient)
                          .order(:created_at)
    
    # Mark messages as read
    @messages.where(recipient: current_user, read_at: nil).update_all(read_at: Time.current)
    
    @new_message = ChatMessage.new
    
    # Load more messages if requested
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 50
    @messages = @messages.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def create
    @message = current_user.sent_messages.build(message_params)
    @message.recipient = @conversation_partner
    @message.message_type ||= 'text'
    
    respond_to do |format|
      if @message.save
        # Broadcast the message via ActionCable (we'll implement this later)
        # ActionCable.server.broadcast "conversation_#{conversation_channel_name}", {
        #   message: render_to_string(partial: 'messages/message', locals: { message: @message }),
        #   sender_id: current_user.id
        # }
        
        format.json { 
          render json: { 
            success: true, 
            message: {
              id: @message.id,
              content: @message.content,
              sender_id: @message.sender_id,
              created_at: @message.created_at.iso8601
            }
          } 
        }
        format.html { redirect_to message_path(@conversation_partner) }
      else
        format.json { render json: { success: false, errors: @message.errors.full_messages }, status: :unprocessable_entity }
        format.html { 
          @messages = ChatMessage.between_users(current_user, @conversation_partner).order(:created_at)
          render :show 
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { success: false, errors: [e.message] }, status: :internal_server_error }
      format.html { 
        flash[:alert] = "Error: #{e.message}"
        redirect_back(fallback_location: conversations_messages_path)
      }
    end
  end

  def destroy
    authorize @message
    if @message.sender == current_user
      @message.destroy
      respond_to do |format|
        format.json { render json: { success: true } }
        format.html { redirect_back(fallback_location: conversations_messages_path) }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: 'Unauthorized' } }
        format.html { redirect_back(fallback_location: conversations_messages_path, alert: 'Unauthorized') }
      end
    end
  end
  
  def mark_as_read
    messages = current_user.received_messages.where(sender_id: params[:sender_id], read_at: nil)
    messages.update_all(read_at: Time.current)
    
    render json: { success: true, count: messages.count }
  end
  
  def search_users
    query = params[:q].to_s.strip
    
    if query.present?
      @users = User.where.not(id: current_user.id)
                   .where("email ILIKE ? OR CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, '')) ILIKE ?", 
                          "%#{query}%", "%#{query}%")
                   .includes(:department)
                   .limit(10)
    else
      @users = []
    end
    
    render json: @users.map { |user| 
      {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department&.name,
        avatar_url: nil # We can add avatar support later
      }
    }
  end

  private

  def set_message
    @message = ChatMessage.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to conversations_messages_path, alert: 'Message not found'
  end
  
  def set_conversation_partner
    if params[:user_id].present?
      @conversation_partner = User.find(params[:user_id])
    elsif params[:id].present?
      @conversation_partner = User.find(params[:id])
    else
      redirect_to conversations_messages_path, alert: 'Conversation partner not specified'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to conversations_messages_path, alert: 'User not found'
  end

  def message_params
    params.require(:chat_message).permit(:content, :message_type)
  end
  
  def conversation_channel_name
    user_ids = [current_user.id, @conversation_partner.id].sort
    "#{user_ids[0]}_#{user_ids[1]}"
  end
end
