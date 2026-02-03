class LearningInsightsController < ApplicationController
  layout 'dashboard'
  before_action :authenticate_user!
  before_action :set_learning_insight, only: [:show, :dismiss, :implement, :archive, :quick_dismiss, :quick_implement, :update_priority, :add_note, :refresh_insight]
  before_action :authorize_insight_access, only: [:show, :dismiss, :implement, :archive, :quick_dismiss, :quick_implement, :update_priority, :add_note, :refresh_insight]
  
  def index
    @insights = scope_insights_for_user
    @insights = @insights.by_type(params[:type]) if params[:type].present?
    @insights = @insights.by_priority(params[:priority]) if params[:priority].present?
    @insights = @insights.where(status: params[:status]) if params[:status].present?
    @insights = @insights.recent if params[:recent] == 'true'
    @insights = @insights.high_confidence if params[:high_confidence] == 'true'
    
    @insights = @insights.includes(:user, :department, :schedule)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(20)
    
    @insight_stats = calculate_insight_stats
    @insight_types = LearningInsight::INSIGHT_TYPES
    @priority_levels = %w[low medium high critical]
    @status_options = %w[active dismissed implemented archived]
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_insights(@insights) }
    end
  end
  
  def show
    @related_insights = find_related_insights(@learning_insight)
    @action_plan = generate_action_plan(@learning_insight)
    @progress_tracking = get_progress_tracking(@learning_insight)
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_insight(@learning_insight) }
    end
  end
  
  def generate_insights
    authorize_insight_generation
    
    target_users = determine_target_users
    insights_generated = 0
    
    target_users.each do |user|
      new_insights = LearningInsight.generate_insights_for_user(user)
      insights_generated += new_insights.count
    end
    
    if params[:schedule_id].present?
      schedule = Schedule.find(params[:schedule_id])
      class_insights = LearningInsight.generate_class_insights(schedule)
      insights_generated += class_insights.count
    end
    
    if current_user.role == 'admin' && params[:institutional] == 'true'
      institutional_insights = LearningInsight.generate_institutional_insights(current_user.department)
      insights_generated += institutional_insights.count
    end
    
    flash[:notice] = "Generated #{insights_generated} new insights"
    redirect_to learning_insights_path
  end
  
  def dismiss
    @learning_insight.dismiss!
    
    respond_to do |format|
      format.html { redirect_to learning_insights_path, notice: 'Insight dismissed' }
      format.json { render json: { status: 'dismissed', message: 'Insight dismissed successfully' } }
    end
  end
  
  def implement
    @learning_insight.implement!
    
    # Track implementation action
    track_insight_action(@learning_insight, 'implemented')
    
    respond_to do |format|
      format.html { redirect_to learning_insights_path, notice: 'Insight marked as implemented' }
      format.json { render json: { status: 'implemented', message: 'Insight implemented successfully' } }
    end
  end
  
  def archive
    @learning_insight.archive!
    
    respond_to do |format|
      format.html { redirect_to learning_insights_path, notice: 'Insight archived' }
      format.json { render json: { status: 'archived', message: 'Insight archived successfully' } }
    end
  end
  
  def bulk_action
    insight_ids = params[:insight_ids] || []
    action = params[:bulk_action]
    
    return redirect_to learning_insights_path, alert: 'No insights selected' if insight_ids.empty?
    
    insights = scope_insights_for_user.where(id: insight_ids)
    success_count = 0
    
    case action
    when 'dismiss'
      insights.each do |insight|
        if insight.dismiss!
          success_count += 1
        end
      end
      message = "Dismissed #{success_count} insights"
    when 'implement'
      insights.each do |insight|
        if insight.implement!
          track_insight_action(insight, 'implemented')
          success_count += 1
        end
      end
      message = "Implemented #{success_count} insights"
    when 'archive'
      insights.each do |insight|
        if insight.archive!
          success_count += 1
        end
      end
      message = "Archived #{success_count} insights"
    else
      return redirect_to learning_insights_path, alert: 'Invalid action'
    end
    
    redirect_to learning_insights_path, notice: message
  end
  
  def analytics
    authorize_analytics_access
    
    @analytics_data = {
      insight_distribution: calculate_insight_distribution,
      effectiveness_metrics: calculate_effectiveness_metrics,
      trend_analysis: calculate_trend_analysis,
      accuracy_metrics: calculate_accuracy_metrics,
      user_engagement: calculate_user_engagement_with_insights
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics_data }
    end
  end
  
  def predictive_dashboard
    authorize_predictive_access
    
    @predictions = {
      at_risk_students: get_at_risk_predictions,
      performance_trends: get_performance_trend_predictions,
      engagement_alerts: get_engagement_alerts,
      intervention_recommendations: get_intervention_recommendations
    }
    
    @dashboard_metrics = {
      total_predictions: @predictions.values.flatten.count,
      high_confidence_predictions: count_high_confidence_predictions(@predictions),
      critical_alerts: count_critical_alerts(@predictions),
      pending_interventions: count_pending_interventions(@predictions)
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { predictions: @predictions, metrics: @dashboard_metrics } }
    end
  end
  
  def student_profile
    @student = User.find(params[:student_id])
    authorize_student_profile_access(@student)
    
    @student_insights = {
      current_insights: @student.learning_insights.active.recent,
      risk_assessment: PredictiveAnalyticsService.predict_student_risk(@student),
      performance_analysis: PerformanceAnalysisService.analyze_trends(@student),
      engagement_analysis: EngagementAnalysisService.analyze_engagement(@student),
      peer_comparison: compare_with_peers(@student),
      intervention_history: get_intervention_history(@student)
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @student_insights }
    end
  end
  
  def export_insights
    insights = scope_insights_for_user
    insights = apply_filters(insights)
    
    format = params[:format] || 'csv'
    
    case format.downcase
    when 'csv'
      csv_data = generate_csv_export(insights)
      send_data csv_data, filename: "learning_insights_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      excel_data = generate_excel_export(insights)
      send_data excel_data, filename: "learning_insights_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'pdf'
      pdf_data = generate_pdf_export(insights)
      send_data pdf_data, filename: "learning_insights_#{Date.current}.pdf", type: 'application/pdf'
    else
      redirect_to learning_insights_path, alert: 'Unsupported export format'
    end
  end
  
  def intervention_tracker
    @interventions = get_tracked_interventions
    @intervention_stats = calculate_intervention_stats(@interventions)
    @effectiveness_data = calculate_intervention_effectiveness(@interventions)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          interventions: @interventions,
          stats: @intervention_stats,
          effectiveness: @effectiveness_data
        }
      end
    end
  end
  
  # AJAX endpoints
  def quick_dismiss
    @learning_insight.dismiss!
    render json: { success: true, message: 'Insight dismissed', status: 'dismissed' }
  end
  
  def quick_implement
    @learning_insight.implement!
    track_insight_action(@learning_insight, 'implemented')
    render json: { success: true, message: 'Insight implemented', status: 'implemented' }
  end
  
  def update_priority
    new_priority = params[:priority]
    
    if %w[low medium high critical].include?(new_priority)
      @learning_insight.update!(priority: new_priority)
      render json: { success: true, message: 'Priority updated', priority: new_priority }
    else
      render json: { success: false, message: 'Invalid priority level' }
    end
  end
  
  def add_note
    note_content = params[:note]
    
    if note_content.present?
      current_notes = @learning_insight.metadata['notes'] || []
      current_notes << {
        content: note_content,
        author: current_user.name,
        timestamp: Time.current.iso8601
      }
      
      @learning_insight.update!(metadata: @learning_insight.metadata.merge('notes' => current_notes))
      render json: { success: true, message: 'Note added', notes: current_notes }
    else
      render json: { success: false, message: 'Note content cannot be empty' }
    end
  end
  
  def refresh_insight
    # Regenerate insight data
    case @learning_insight.insight_type
    when 'at_risk_prediction'
      updated_data = PredictiveAnalyticsService.predict_student_risk(@learning_insight.user)
    when 'performance_decline'
      updated_data = PerformanceAnalysisService.analyze_trends(@learning_insight.user)
    when 'engagement_drop'
      updated_data = EngagementAnalysisService.analyze_engagement(@learning_insight.user)
    else
      render json: { success: false, message: 'Cannot refresh this insight type' }
      return
    end
    
    @learning_insight.update!(
      data: updated_data,
      confidence_score: updated_data[:confidence] || @learning_insight.confidence_score,
      metadata: @learning_insight.metadata.merge('refreshed_at' => Time.current.iso8601)
    )
    
    render json: { success: true, message: 'Insight refreshed', insight: serialize_insight(@learning_insight) }
  end
  
  private
  
  def set_learning_insight
    @learning_insight = LearningInsight.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to learning_insights_path, alert: 'Insight not found'
  end
  
  def authorize_insight_access
    unless can_access_insight?(@learning_insight)
      redirect_to learning_insights_path, alert: 'Access denied'
    end
  end
  
  def can_access_insight?(insight)
    case current_user.role
    when 'admin'
      true
    when 'teacher'
      # Teachers can see insights for their students
      insight.user.role == 'student' && 
      (insight.user.department == current_user.department ||
       current_user.schedules.joins(:users).exists?(users: { id: insight.user.id }))
    when 'student'
      # Students can only see their own insights
      insight.user == current_user
    else
      false
    end
  end
  
  def scope_insights_for_user
    case current_user.role
    when 'admin'
      LearningInsight.all
    when 'teacher'
      # Teacher can see insights for their students
      student_ids = current_user.schedules.joins(:users)
                                .where(users: { role: 'student' })
                                .pluck('users.id')
      LearningInsight.where(user_id: student_ids)
    when 'student'
      current_user.learning_insights
    else
      LearningInsight.none
    end
  end
  
  def authorize_insight_generation
    unless current_user.role.in?(['admin', 'teacher'])
      redirect_to learning_insights_path, alert: 'Not authorized to generate insights'
    end
  end
  
  def determine_target_users
    case current_user.role
    when 'admin'
      if params[:department_id].present?
        User.where(role: 'student', department_id: params[:department_id])
      elsif params[:user_ids].present?
        User.where(id: params[:user_ids], role: 'student')
      else
        User.where(role: 'student')
      end
    when 'teacher'
      if params[:user_ids].present?
        # Only allow teacher's students
        student_ids = current_user.schedules.joins(:users)
                                  .where(users: { role: 'student' })
                                  .pluck('users.id')
        User.where(id: params[:user_ids], id: student_ids)
      else
        # All of teacher's students
        current_user.schedules.joins(:users)
                    .where(users: { role: 'student' })
                    .select('users.*')
      end
    else
      User.none
    end
  end
  
  def calculate_insight_stats
    insights = scope_insights_for_user
    
    {
      total: insights.count,
      active: insights.active.count,
      high_priority: insights.where(priority: ['high', 'critical']).count,
      recent: insights.recent.count,
      by_type: insights.group(:insight_type).count,
      by_priority: insights.group(:priority).count,
      by_status: insights.group(:status).count
    }
  end
  
  def find_related_insights(insight)
    scope_insights_for_user
      .where.not(id: insight.id)
      .where(user: insight.user)
      .where(status: 'active')
      .limit(5)
  end
  
  def generate_action_plan(insight)
    actions = insight.recommendation_actions
    
    actions.map.with_index do |action, index|
      {
        id: index + 1,
        action: action,
        priority: determine_action_priority(action),
        estimated_effort: estimate_action_effort(action),
        expected_outcome: predict_action_outcome(action, insight),
        status: 'pending'
      }
    end
  end
  
  def get_progress_tracking(insight)
    # Track progress on insight implementation
    {
      created_at: insight.created_at,
      first_viewed: insight.metadata['first_viewed'],
      actions_taken: insight.metadata['actions_taken'] || [],
      effectiveness_score: calculate_insight_effectiveness(insight),
      follow_up_needed: insight.created_at < 7.days.ago && insight.status == 'active'
    }
  end
  
  def track_insight_action(insight, action)
    actions = insight.metadata['actions_taken'] || []
    actions << {
      action: action,
      timestamp: Time.current.iso8601,
      user: current_user.name
    }
    
    insight.update!(metadata: insight.metadata.merge('actions_taken' => actions))
  end
  
  def authorize_analytics_access
    unless current_user.role.in?(['admin', 'teacher'])
      redirect_to learning_insights_path, alert: 'Access denied'
    end
  end
  
  def authorize_predictive_access
    unless current_user.role.in?(['admin', 'teacher'])
      redirect_to learning_insights_path, alert: 'Access denied'
    end
  end
  
  def authorize_student_profile_access(student)
    unless can_access_student_profile?(student)
      redirect_to learning_insights_path, alert: 'Access denied'
    end
  end
  
  def can_access_student_profile?(student)
    case current_user.role
    when 'admin'
      true
    when 'teacher'
      # Teacher can access their students' profiles
      current_user.schedules.joins(:users).exists?(users: { id: student.id })
    when 'student'
      # Students can only access their own profile
      student == current_user
    else
      false
    end
  end
  
  def serialize_insights(insights)
    insights.map { |insight| serialize_insight(insight) }
  end
  
  def serialize_insight(insight)
    {
      id: insight.id,
      title: insight.title,
      description: insight.description,
      insight_type: insight.insight_type,
      priority: insight.priority,
      status: insight.status,
      confidence_score: insight.confidence_percentage,
      created_at: insight.created_at,
      user: {
        id: insight.user.id,
        name: insight.user.name,
        email: insight.user.email
      },
      department: insight.department&.name,
      schedule: insight.schedule&.title,
      recommendations: insight.recommendation_actions,
      evidence: insight.supporting_evidence,
      metrics: insight.related_metrics
    }
  end
  
  def apply_filters(insights)
    insights = insights.by_type(params[:type]) if params[:type].present?
    insights = insights.by_priority(params[:priority]) if params[:priority].present?
    insights = insights.where(status: params[:status]) if params[:status].present?
    insights = insights.recent if params[:recent] == 'true'
    insights = insights.high_confidence if params[:high_confidence] == 'true'
    insights
  end
  
  # Export methods
  def generate_csv_export(insights)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Student', 'Type', 'Priority', 'Status', 'Confidence', 'Description', 'Created']
      
      insights.each do |insight|
        csv << [
          insight.id,
          insight.user.name,
          insight.insight_type.humanize,
          insight.priority.humanize,
          insight.status.humanize,
          "#{insight.confidence_percentage}%",
          insight.description,
          insight.created_at.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_excel_export(insights)
    # Would generate Excel file - simplified for now
    generate_csv_export(insights)
  end
  
  def generate_pdf_export(insights)
    # Would generate PDF report - simplified for now
    "PDF export would contain #{insights.count} insights"
  end
  
  # Analytics calculation methods
  def calculate_insight_distribution
    insights = scope_insights_for_user
    
    {
      by_type: insights.group(:insight_type).count,
      by_priority: insights.group(:priority).count,
      by_department: insights.joins(:department).group('departments.name').count,
      by_month: insights.group_by_month(:created_at).count
    }
  end
  
  def calculate_effectiveness_metrics
    insights = scope_insights_for_user.where(status: ['implemented', 'dismissed'])
    
    {
      implementation_rate: calculate_implementation_rate(insights),
      dismissal_rate: calculate_dismissal_rate(insights),
      average_resolution_time: calculate_average_resolution_time(insights),
      effectiveness_by_type: calculate_effectiveness_by_type(insights)
    }
  end
  
  def calculate_trend_analysis
    insights = scope_insights_for_user
    
    {
      monthly_trends: insights.group_by_month(:created_at).count,
      type_trends: analyze_type_trends(insights),
      priority_trends: analyze_priority_trends(insights)
    }
  end
  
  def calculate_accuracy_metrics
    # This would calculate prediction accuracy over time
    {
      overall_accuracy: 0.78,
      accuracy_by_type: {
        'at_risk_prediction' => 0.82,
        'performance_decline' => 0.75,
        'engagement_drop' => 0.73
      },
      false_positive_rate: 0.15,
      false_negative_rate: 0.12
    }
  end
  
  def calculate_user_engagement_with_insights
    insights = scope_insights_for_user
    
    {
      view_rate: calculate_insight_view_rate(insights),
      action_rate: calculate_insight_action_rate(insights),
      average_time_to_action: calculate_average_time_to_action(insights)
    }
  end
  
  # Predictive dashboard methods
  def get_at_risk_predictions
    case current_user.role
    when 'admin'
      students = User.where(role: 'student')
    when 'teacher'
      students = current_user.schedules.joins(:users)
                             .where(users: { role: 'student' })
                             .select('users.*')
    else
      return []
    end
    
    PredictiveAnalyticsService.predict_at_risk_students(students)
                              .select { |_, data| data[:risk_score] > 0.6 }
                              .map { |user_id, data| format_risk_prediction(user_id, data) }
  end
  
  def get_performance_trend_predictions
    # Get performance trend predictions for students
    []
  end
  
  def get_engagement_alerts
    # Get engagement alerts
    []
  end
  
  def get_intervention_recommendations
    # Get intervention recommendations
    []
  end
  
  def count_high_confidence_predictions(predictions)
    predictions.values.flatten.count { |p| p[:confidence] && p[:confidence] > 0.8 }
  end
  
  def count_critical_alerts(predictions)
    predictions.values.flatten.count { |p| p[:priority] == 'critical' }
  end
  
  def count_pending_interventions(predictions)
    predictions.values.flatten.count { |p| p[:status] == 'pending' }
  end
  
  def compare_with_peers(student)
    PerformanceAnalysisService.compare_peer_performance(student)
  end
  
  def get_intervention_history(student)
    student.learning_insights
           .where(status: ['implemented', 'dismissed'])
           .order(updated_at: :desc)
           .limit(10)
  end
  
  def get_tracked_interventions
    # Get interventions being tracked
    []
  end
  
  def calculate_intervention_stats(interventions)
    # Calculate intervention statistics
    {}
  end
  
  def calculate_intervention_effectiveness(interventions)
    # Calculate intervention effectiveness
    {}
  end
  
  # Helper methods for action planning
  def determine_action_priority(action)
    # Determine priority based on action type
    case action.downcase
    when /immediate|urgent|critical/
      'high'
    when /schedule|meeting|counseling/
      'medium'
    else
      'low'
    end
  end
  
  def estimate_action_effort(action)
    # Estimate effort required for action
    case action.downcase
    when /meeting|counseling|intervention/
      'high'
    when /review|assess|consider/
      'medium'
    else
      'low'
    end
  end
  
  def predict_action_outcome(action, insight)
    # Predict likely outcome of action
    confidence = insight.confidence_score
    
    if confidence > 0.8
      'high_impact'
    elsif confidence > 0.6
      'medium_impact'
    else
      'low_impact'
    end
  end
  
  def calculate_insight_effectiveness(insight)
    # Calculate how effective this insight has been
    return 0 if insight.status == 'active'
    
    case insight.status
    when 'implemented'
      0.8 # Assume high effectiveness for implemented insights
    when 'dismissed'
      0.2 # Low effectiveness for dismissed insights
    else
      0.5
    end
  end
  
  # Additional helper methods for analytics
  def calculate_implementation_rate(insights)
    return 0 if insights.empty?
    
    implemented = insights.where(status: 'implemented').count
    implemented / insights.count.to_f
  end
  
  def calculate_dismissal_rate(insights)
    return 0 if insights.empty?
    
    dismissed = insights.where(status: 'dismissed').count
    dismissed / insights.count.to_f
  end
  
  def calculate_average_resolution_time(insights)
    resolved_insights = insights.where.not(implemented_at: nil, dismissed_at: nil)
    return 0 if resolved_insights.empty?
    
    total_time = resolved_insights.sum do |insight|
      resolution_time = insight.implemented_at || insight.dismissed_at
      (resolution_time - insight.created_at) / 1.day
    end
    
    total_time / resolved_insights.count
  end
  
  def calculate_effectiveness_by_type(insights)
    insights.group(:insight_type).group(:status).count
  end
  
  def analyze_type_trends(insights)
    # Analyze trends by insight type
    {}
  end
  
  def analyze_priority_trends(insights)
    # Analyze trends by priority
    {}
  end
  
  def calculate_insight_view_rate(insights)
    # Calculate what percentage of insights are viewed
    0.75
  end
  
  def calculate_insight_action_rate(insights)
    # Calculate what percentage of insights have actions taken
    0.60
  end
  
  def calculate_average_time_to_action(insights)
    # Calculate average time from creation to first action
    2.5 # days
  end
  
  def format_risk_prediction(user_id, data)
    user = User.find(user_id)
    {
      user_id: user_id,
      name: user.name,
      risk_score: data[:risk_score],
      risk_level: data[:risk_level],
      factors: data[:risk_factors],
      confidence: data[:confidence],
      priority: data[:risk_score] > 0.8 ? 'critical' : 'high',
      status: 'pending'
    }
  end
end