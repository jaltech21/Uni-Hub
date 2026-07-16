module Api
  module V1
    class AuthenticationController < BaseController
      skip_before_action :authenticate_user!, only: [:login, :register, :refresh]

      def login
        user = User.find_for_authentication(email: params[:email].to_s.downcase.strip)

        return render_error("Invalid email or password", status: :unauthorized, code: "AUTH_FAILED") if user.nil?
        return render_error("Invalid email or password", status: :unauthorized, code: "AUTH_FAILED") unless user.valid_password?(params[:password])
        return render_error("Account inactive", status: :unauthorized, code: "ACCOUNT_INACTIVE") unless user.active_for_authentication?

        render_token_payload(user, status: :ok)
      end

      def register
        user = User.new(registration_params)

        if user.save
          render_token_payload(user, status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: user.errors.messages
          )
        end
      end

      def refresh
        raw = bearer_token
        return render_error("Refresh token required", status: :unauthorized, code: "REFRESH_FAILED") if raw.blank?

        record = RefreshToken.find_active(raw)
        return render_error("Refresh token expired or invalid", status: :unauthorized, code: "REFRESH_FAILED") if record.nil?
        return render_error("Account inactive", status: :unauthorized, code: "ACCOUNT_INACTIVE") unless record.user.active_for_authentication?

        record.revoke!
        render_token_payload(record.user, status: :ok, include_user: false)
      end

      def current_user_profile
        render_success(user_profile(current_user, full: true))
      end

      def logout
        raw = params[:refresh_token].presence
        if raw.present?
          record = RefreshToken.find_active(raw)
          record&.revoke! if record&.user_id == current_user.id
        end
        render_message("Logged out successfully")
      end

      private

      def registration_params
        params.permit(:first_name, :last_name, :email, :username, :password, :password_confirmation, :role, :department_id)
      end

      def render_token_payload(user, status:, include_user: true)
        access_token = JsonWebToken.encode({ sub: user.id, type: "access" })
        _record, raw_refresh = RefreshToken.issue!(
          user,
          user_agent: request.user_agent,
          ip_address: request.remote_ip
        )

        payload = { token: access_token, refresh_token: raw_refresh, expires_in: ACCESS_TOKEN_LIFETIME.to_i }
        payload[:user] = user_profile(user) if include_user
        render_success(payload, status: status)
      end

      def user_profile(user, full: false)
        attrs = {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          username: user.username,
          role: user.role,
          department_id: user.department_id,
          profile_picture_url: nil
        }
        if full
          attrs.merge!(
            department_name: user.department&.name,
            created_at: user.created_at,
            updated_at: user.updated_at
          )
        end
        attrs
      end
    end
  end
end
