module Admin
  class AiAnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    
    def index
      @time_period = params[:period] || 'today'
      
      # Get base scope based on time period
      @logs = case @time_period
              when 'today'
                AiUsageLog.today
              when 'week'
                AiUsageLog.this_week
              when 'month'
                AiUsageLog.this_month
              else
                AiUsageLog.recent
              end
      
      # Overall statistics
      @total_requests = @logs.count
      @success_rate = @logs.success_rate
      @average_processing_time = @logs.average_processing_time
      @total_tokens = @logs.total_tokens_used
      
      # Breakdown by action
      @stats_by_action = @logs.stats_by_action
      
      # Success/failure breakdown
      @successful_count = @logs.successful.count
      @failed_count = @logs.failed.count
      @rate_limited_count = @logs.rate_limited.count
      
      # Daily stats for chart (last 7 days)
      @daily_stats = AiUsageLog.daily_stats(7)
      
      # Top users by usage
      @top_users = @logs.group(:user_id)
                        .select('user_id, COUNT(*) as request_count')
                        .order('request_count DESC')
                        .limit(10)
      
      # Recent logs for table
      @recent_logs = @logs.includes(:user).limit(50)
      
      # Success rate by action
      @success_by_action = {}
      %w[summarize_text generate_questions get_study_hints].each do |action|
        action_logs = @logs.by_action(action)
        total = action_logs.count
        successful = action_logs.successful.count
        @success_by_action[action] = total > 0 ? (successful.to_f / total * 100).round(1) : 0
      end
    end
    
    private
    
    def require_admin
      # TODO: Implement proper admin check
      # For now, just check if user exists
      # You should add an admin boolean or role system to User model
      unless current_user.present?
        redirect_to root_path, alert: "Access denied. Admin privileges required."
      end
    end
  end
end
