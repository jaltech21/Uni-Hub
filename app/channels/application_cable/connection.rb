module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable connected: User #{current_user.id}"
    end

    def disconnect
      Rails.logger.info "ActionCable disconnected: User #{current_user&.id}"
    end

    private

    def find_verified_user
      # Try to get user from session (for same-domain connections)
      if session_user = User.find_by(id: session[:user_id])
        return session_user
      end
      
      # Try to get user from cookies (for Devise)
      if cookies.signed[:user_id]
        user = User.find_by(id: cookies.signed[:user_id])
        return user if user
      end
      
      # Try to authenticate via Warden (Devise's authentication layer)
      if env['warden']&.user
        return env['warden'].user
      end
      
      # If all methods fail, reject the connection
      reject_unauthorized_connection
    end
    
    private
    
    def session
      @session ||= cookies.encrypted[Rails.application.config.session_options[:key]]
    end
  end
end
