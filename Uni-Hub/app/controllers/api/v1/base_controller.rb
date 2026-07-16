module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization

      ACCESS_TOKEN_LIFETIME = JsonWebToken::ACCESS_TOKEN_LIFETIME

      attr_reader :current_user

      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound,   with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid,    with: :render_validation_errors
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from Pundit::NotAuthorizedError,     with: :render_forbidden
      # Register the broader handler first; rescue_from searches bottom-up so
      # the more specific ExpiredError handler must come last to take priority.
      rescue_from JsonWebToken::DecodeError,      with: :render_unauthorized
      rescue_from JsonWebToken::ExpiredError,     with: :render_token_expired

      protected

      def authenticate_user!
        token = bearer_token
        return render_unauthorized("Authorization token required") if token.blank?

        payload = JsonWebToken.decode(token)
        return render_unauthorized("Invalid token type") unless payload[:type] == "access"

        @current_user = User.find_by(id: payload[:sub])
        return render_unauthorized("User not found") if @current_user.nil?
        return render_unauthorized("Account inactive") unless @current_user.active_for_authentication?
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        header.start_with?("Bearer ") ? header.split(" ", 2).last : nil
      end

      def render_success(data, status: :ok, meta: nil)
        body = { success: true, data: data }
        body[:meta] = meta if meta
        render json: body, status: status
      end

      def render_message(message, status: :ok)
        render json: { success: true, message: message }, status: status
      end

      def render_error(message, status:, code: nil, errors: nil)
        body = { success: false, error: { status: Rack::Utils.status_code(status), message: message } }
        body[:error][:code]   = code   if code
        body[:error][:errors] = errors if errors
        render json: body, status: status
      end

      def render_unauthorized(message = "Unauthorized")
        render_error(message, status: :unauthorized, code: "TOKEN_INVALID")
      end

      def render_token_expired
        render_error("Access token expired", status: :unauthorized, code: "TOKEN_EXPIRED")
      end

      def render_forbidden(_exception = nil)
        render_error("You are not authorized to perform this action", status: :forbidden, code: "FORBIDDEN")
      end

      def render_not_found(_exception = nil)
        render_error("Resource not found", status: :not_found, code: "NOT_FOUND")
      end

      def render_bad_request(exception)
        render_error(exception.message, status: :bad_request, code: "BAD_REQUEST")
      end

      def render_validation_errors(exception)
        render_error(
          "Validation failed",
          status: :unprocessable_entity,
          code: "VALIDATION_ERROR",
          errors: exception.record.errors.messages
        )
      end

      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 20

      def paginate(relation)
        per_page = [params[:per_page].to_i, MAX_PER_PAGE].min
        per_page = DEFAULT_PER_PAGE if per_page <= 0
        relation.page(params[:page]).per(per_page)
      end

      def pagination_meta(collection)
        {
          page: collection.current_page,
          per_page: collection.limit_value,
          total: collection.total_count,
          total_pages: collection.total_pages
        }
      end
    end
  end
end
