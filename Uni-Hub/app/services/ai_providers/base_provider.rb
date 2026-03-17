# frozen_string_literal: true

module AiProviders
  class BaseProvider
    attr_reader :api_key, :rate_limiter

    def initialize(api_key:)
      @api_key = api_key
      @rate_limiter = RateLimiter.new
    end

    # Abstract methods that must be implemented by subclasses
    def summarize_text(text, length:, user_id:)
      raise NotImplementedError, "#{self.class} must implement #summarize_text"
    end

    def generate_questions(text, question_type:, count:, difficulty:, user_id:)
      raise NotImplementedError, "#{self.class} must implement #generate_questions"
    end

    def get_study_hints(topic, user_id:)
      raise NotImplementedError, "#{self.class} must implement #get_study_hints"
    end

    # Shared rate limiting methods
    def can_make_request?(user_id)
      @rate_limiter.can_make_request?(user_id)
    end

    def remaining_requests(user_id)
      @rate_limiter.remaining_requests(user_id)
    end

    def max_requests_per_hour
      @rate_limiter.max_requests_per_hour
    end

    protected

    # Shared logging methods
    def log_request(user_id, action, details = {})
      Rails.logger.info "AI Request - User: #{user_id}, Action: #{action}, Provider: #{provider_name}, Details: #{details}"
    end

    def log_success(user_id, action, processing_time, tokens_used = nil)
      Rails.logger.info "AI Success - User: #{user_id}, Action: #{action}, Provider: #{provider_name}, Time: #{processing_time}s, Tokens: #{tokens_used}"
      
      AiUsageLog.create!(
        user_id: user_id,
        action: action,
        status: 'success',
        processing_time: processing_time,
        tokens_used: tokens_used,
        provider: provider_name,
        response_details: { provider: provider_name }
      )
    end

    def log_failure(user_id, action, error, processing_time = nil)
      Rails.logger.error "AI Failure - User: #{user_id}, Action: #{action}, Provider: #{provider_name}, Error: #{error.message}"
      
      AiUsageLog.create!(
        user_id: user_id,
        action: action,
        status: 'failure',
        error_message: error.message,
        processing_time: processing_time,
        provider: provider_name,
        response_details: { provider: provider_name }
      )
    end

    def log_rate_limit(user_id, action)
      Rails.logger.warn "AI Rate Limited - User: #{user_id}, Action: #{action}, Provider: #{provider_name}"
      
      AiUsageLog.create!(
        user_id: user_id,
        action: action,
        status: 'rate_limited',
        error_message: "Rate limit exceeded for user #{user_id}",
        provider: provider_name,
        response_details: { provider: provider_name }
      )
    end

    # Helper to get provider name from class
    def provider_name
      self.class.name.demodulize.gsub('Provider', '').downcase
    end

    # Rate Limiter class (shared across all providers)
    class RateLimiter
      attr_reader :max_requests_per_hour

      def initialize(max_requests_per_hour = 50)
        @max_requests_per_hour = max_requests_per_hour
        @requests = {}
        @mutex = Mutex.new
      end

      def can_make_request?(user_id)
        @mutex.synchronize do
          cleanup_old_requests(user_id)
          user_requests = @requests[user_id] || []
          user_requests.size < @max_requests_per_hour
        end
      end

      def record_request(user_id)
        @mutex.synchronize do
          @requests[user_id] ||= []
          @requests[user_id] << Time.current
        end
      end

      def remaining_requests(user_id)
        @mutex.synchronize do
          cleanup_old_requests(user_id)
          user_requests = @requests[user_id] || []
          @max_requests_per_hour - user_requests.size
        end
      end

      def reset_limiter(user_id = nil)
        @mutex.synchronize do
          if user_id
            @requests.delete(user_id)
          else
            @requests.clear
          end
        end
      end

      private

      def cleanup_old_requests(user_id)
        return unless @requests[user_id]

        one_hour_ago = 1.hour.ago
        @requests[user_id].reject! { |time| time < one_hour_ago }
        @requests.delete(user_id) if @requests[user_id].empty?
      end
    end
  end
end
