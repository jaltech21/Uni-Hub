class PredictiveAnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_predictive_access
  before_action :set_predictive_analytic, only: [:show, :edit, :update, :destroy, :run_prediction, :update_model]
  
  def index
    @predictions = PredictiveAnalytic.includes(:campus, :department)
                                   .by_prediction_type(params[:prediction_type])
                                   .by_status(params[:status])
                                   .by_accuracy_range(params[:min_accuracy], params[:max_accuracy])
                                   .recent
                                   .page(params[:page])
                                   .per(20)
    
    @prediction_summary = {
      total_predictions: PredictiveAnalytic.count,
      active_models: PredictiveAnalytic.where(status: 'active').count,
      average_accuracy: PredictiveAnalytic.where.not(accuracy_score: nil).average(:accuracy_score)&.round(2),
      predictions_today: PredictiveAnalytic.where('updated_at >= ?', Date.current.beginning_of_day).count
    }
    
    @prediction_types = PredictiveAnalytic.distinct.pluck(:prediction_type)
    
    respond_to do |format|
      format.html
      format.json { render json: { predictions: @predictions, summary: @prediction_summary } }
    end
  end
  
  def show
    @prediction_results = @predictive_analytic.prediction_results || {}
    @model_performance = @predictive_analytic.model_performance_metrics
    @feature_importance = @predictive_analytic.feature_importance || {}
    @prediction_history = @predictive_analytic.prediction_history.last(10)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: @predictive_analytic.as_json(
          include: [:campus, :department],
          methods: [:model_performance_metrics, :prediction_confidence]
        )
      }
    end
  end
  
  def new
    @predictive_analytic = PredictiveAnalytic.new
    @campuses = Campus.all
    @departments = Department.all
    @prediction_templates = get_prediction_templates
  end
  
  def create
    @predictive_analytic = PredictiveAnalytic.new(predictive_analytic_params)
    
    if @predictive_analytic.save
      # Initialize model training based on prediction type
      case @predictive_analytic.prediction_type
      when 'student_success'
        @predictive_analytic.train_student_success_model!
      when 'dropout_risk'
        @predictive_analytic.train_dropout_model!
      when 'grade_prediction'
        @predictive_analytic.train_grade_model!
      when 'resource_optimization'
        @predictive_analytic.train_resource_model!
      end
      
      redirect_to @predictive_analytic, notice: 'Predictive model created and training initiated.'
    else
      @campuses = Campus.all
      @departments = Department.all
      @prediction_templates = get_prediction_templates
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @campuses = Campus.all
    @departments = Department.all
  end
  
  def update
    if @predictive_analytic.update(predictive_analytic_params)
      redirect_to @predictive_analytic, notice: 'Predictive model updated successfully.'
    else
      @campuses = Campus.all
      @departments = Department.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @predictive_analytic.destroy
    redirect_to predictive_analytics_url, notice: 'Predictive model was successfully deleted.'
  end
  
  def run_prediction
    target_data = params[:target_data] || {}
    
    begin
      case @predictive_analytic.prediction_type
      when 'student_success'
        results = @predictive_analytic.predict_student_success(target_data)
      when 'dropout_risk'
        results = @predictive_analytic.predict_dropout_risk(target_data)
      when 'grade_prediction'
        results = @predictive_analytic.predict_grades(target_data)
      when 'resource_optimization'
        results = @predictive_analytic.predict_resource_needs(target_data)
      else
        results = { error: 'Unknown prediction type' }
      end
      
      if results[:error]
        redirect_to @predictive_analytic, alert: "Prediction failed: #{results[:error]}"
      else
        @predictive_analytic.update!(
          prediction_results: results,
          last_prediction_at: Time.current
        )
        redirect_to @predictive_analytic, notice: 'Prediction completed successfully.'
      end
    rescue => e
      redirect_to @predictive_analytic, alert: "Prediction failed: #{e.message}"
    end
  end
  
  def update_model
    begin
      case @predictive_analytic.prediction_type
      when 'student_success'
        @predictive_analytic.retrain_student_success_model!
      when 'dropout_risk'
        @predictive_analytic.retrain_dropout_model!
      when 'grade_prediction'
        @predictive_analytic.retrain_grade_model!
      when 'resource_optimization'
        @predictive_analytic.retrain_resource_model!
      end
      
      redirect_to @predictive_analytic, notice: 'Model retraining initiated. This may take several minutes.'
    rescue => e
      redirect_to @predictive_analytic, alert: "Model update failed: #{e.message}"
    end
  end
  
  def dashboard
    @dashboard_metrics = {
      total_models: PredictiveAnalytic.count,
      active_models: PredictiveAnalytic.where(status: 'active').count,
      models_training: PredictiveAnalytic.where(status: 'training').count,
      average_accuracy: PredictiveAnalytic.where.not(accuracy_score: nil).average(:accuracy_score)&.round(2) || 0
    }
    
    @model_performance = {
      accuracy_distribution: calculate_accuracy_distribution,
      performance_by_type: calculate_performance_by_type,
      model_usage_trends: calculate_model_usage_trends,
      top_performing_models: get_top_performing_models
    }
    
    @recent_predictions = get_recent_predictions
    @model_alerts = check_model_alerts
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          metrics: @dashboard_metrics, 
          performance: @model_performance, 
          predictions: @recent_predictions,
          alerts: @model_alerts 
        } 
      }
    end
  end
  
  def batch_predictions
    prediction_requests = params[:batch_data] || []
    model_id = params[:model_id]
    
    unless model_id.present?
      return redirect_to predictive_analytics_path, alert: 'Model ID required for batch predictions'
    end
    
    model = PredictiveAnalytic.find(model_id)
    
    begin
      batch_results = model.run_batch_predictions(prediction_requests)
      
      render json: {
        success: true,
        results: batch_results,
        processed_count: batch_results.count,
        model_accuracy: model.accuracy_score
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end
  
  def student_risk_assessment
    @risk_assessment = {
      high_risk_students: identify_high_risk_students,
      medium_risk_students: identify_medium_risk_students,
      intervention_recommendations: generate_intervention_recommendations,
      early_warning_indicators: calculate_early_warning_indicators
    }
    
    @risk_trends = {
      risk_by_department: calculate_risk_by_department,
      risk_by_campus: calculate_risk_by_campus,
      risk_over_time: calculate_risk_trends_over_time,
      success_rate_predictions: calculate_success_rate_predictions
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { assessment: @risk_assessment, trends: @risk_trends } }
    end
  end
  
  def academic_forecasting
    @academic_forecasts = {
      enrollment_projections: generate_enrollment_projections,
      grade_distribution_forecasts: generate_grade_distribution_forecasts,
      graduation_rate_predictions: generate_graduation_rate_predictions,
      course_demand_forecasts: generate_course_demand_forecasts
    }
    
    @forecast_accuracy = {
      historical_accuracy: calculate_historical_forecast_accuracy,
      confidence_intervals: calculate_forecast_confidence_intervals,
      seasonal_adjustments: calculate_seasonal_adjustments
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { forecasts: @academic_forecasts, accuracy: @forecast_accuracy } }
    end
  end
  
  def resource_optimization
    @optimization_analysis = {
      facility_utilization_predictions: predict_facility_utilization,
      staff_allocation_recommendations: recommend_staff_allocation,
      budget_optimization_suggestions: suggest_budget_optimizations,
      equipment_needs_forecasting: forecast_equipment_needs
    }
    
    @efficiency_metrics = {
      current_efficiency_scores: calculate_current_efficiency,
      predicted_improvements: calculate_predicted_improvements,
      cost_benefit_analysis: perform_cost_benefit_analysis,
      optimization_priorities: identify_optimization_priorities
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { optimization: @optimization_analysis, efficiency: @efficiency_metrics } }
    end
  end
  
  def model_comparison
    @comparison_metrics = {
      accuracy_comparison: compare_model_accuracy,
      performance_comparison: compare_model_performance,
      feature_importance_comparison: compare_feature_importance,
      prediction_speed_comparison: compare_prediction_speed
    }
    
    @model_recommendations = {
      best_performing_models: identify_best_performing_models,
      model_selection_guidance: provide_model_selection_guidance,
      ensemble_opportunities: identify_ensemble_opportunities
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { comparison: @comparison_metrics, recommendations: @model_recommendations } }
    end
  end
  
  def export_predictions
    model = PredictiveAnalytic.find(params[:id])
    date_range = parse_date_range(params[:start_date], params[:end_date])
    
    case params[:format]
    when 'csv'
      csv_data = model.export_predictions_to_csv(date_range)
      send_data csv_data, 
                filename: "predictions_#{model.prediction_type}_#{Date.current.strftime('%Y%m%d')}.csv",
                type: 'text/csv'
      
    when 'json'
      json_data = model.export_predictions_to_json(date_range)
      send_data json_data,
                filename: "predictions_#{model.prediction_type}_#{Date.current.strftime('%Y%m%d')}.json",
                type: 'application/json'
      
    when 'excel'
      excel_file = model.export_predictions_to_excel(date_range)
      send_file excel_file,
                filename: "predictions_#{model.prediction_type}_#{Date.current.strftime('%Y%m%d')}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      
    else
      redirect_to model, alert: 'Invalid export format'
    end
  end
  
  private
  
  def set_predictive_analytic
    @predictive_analytic = PredictiveAnalytic.find(params[:id])
  end
  
  def predictive_analytic_params
    params.require(:predictive_analytic).permit(
      :model_name, :prediction_type, :campus_id, :department_id,
      :target_variable, :status, :model_algorithm,
      training_data: {}, model_parameters: {}, feature_columns: []
    )
  end
  
  def require_predictive_access
    unless current_user.admin? || current_user.analytics_manager? || current_user.department_head?
      redirect_to root_path, alert: 'Access denied. Predictive Analytics privileges required.'
    end
  end
  
  def get_prediction_templates
    [
      {
        name: 'Student Success Prediction',
        type: 'student_success',
        description: 'Predict likelihood of student academic success based on historical data',
        target_variable: 'success_probability',
        recommended_algorithm: 'random_forest'
      },
      {
        name: 'Dropout Risk Assessment',
        type: 'dropout_risk',
        description: 'Identify students at risk of dropping out for early intervention',
        target_variable: 'dropout_risk_score',
        recommended_algorithm: 'logistic_regression'
      },
      {
        name: 'Grade Prediction',
        type: 'grade_prediction',
        description: 'Forecast student grades to identify support needs',
        target_variable: 'predicted_grade',
        recommended_algorithm: 'gradient_boosting'
      },
      {
        name: 'Resource Optimization',
        type: 'resource_optimization',
        description: 'Predict resource needs and optimization opportunities',
        target_variable: 'resource_demand',
        recommended_algorithm: 'linear_regression'
      },
      {
        name: 'Enrollment Forecasting',
        type: 'enrollment_forecasting',
        description: 'Forecast future enrollment trends for capacity planning',
        target_variable: 'enrollment_count',
        recommended_algorithm: 'time_series'
      }
    ]
  end
  
  def calculate_accuracy_distribution
    accuracies = PredictiveAnalytic.where.not(accuracy_score: nil).pluck(:accuracy_score)
    
    return {} if accuracies.empty?
    
    {
      excellent: accuracies.count { |a| a >= 0.9 },
      good: accuracies.count { |a| a >= 0.8 && a < 0.9 },
      fair: accuracies.count { |a| a >= 0.7 && a < 0.8 },
      poor: accuracies.count { |a| a < 0.7 }
    }
  end
  
  def calculate_performance_by_type
    PredictiveAnalytic.joins("LEFT JOIN (
      SELECT prediction_type, AVG(accuracy_score) as avg_accuracy, COUNT(*) as model_count
      FROM predictive_analytics 
      WHERE accuracy_score IS NOT NULL 
      GROUP BY prediction_type
    ) pa ON predictive_analytics.prediction_type = pa.prediction_type")
    .group(:prediction_type)
    .pluck(:prediction_type, 'AVG(pa.avg_accuracy)', 'MAX(pa.model_count)')
    .map { |type, avg_acc, count| [type, { accuracy: avg_acc&.round(3), count: count }] }
    .to_h
  end
  
  def get_top_performing_models
    PredictiveAnalytic.where.not(accuracy_score: nil)
                    .order(accuracy_score: :desc)
                    .limit(5)
                    .pluck(:model_name, :prediction_type, :accuracy_score)
                    .map { |name, type, acc| { name: name, type: type, accuracy: acc.round(3) } }
  end
  
  def get_recent_predictions
    PredictiveAnalytic.where('last_prediction_at >= ?', 7.days.ago)
                    .order(last_prediction_at: :desc)
                    .limit(10)
                    .pluck(:model_name, :prediction_type, :last_prediction_at)
                    .map { |name, type, time| { model: name, type: type, timestamp: time } }
  end
  
  def check_model_alerts
    alerts = []
    
    # Low accuracy alerts
    low_accuracy_models = PredictiveAnalytic.where('accuracy_score < ?', 0.7)
    if low_accuracy_models.exists?
      alerts << {
        type: 'warning',
        message: "#{low_accuracy_models.count} model(s) have accuracy below 70%",
        action: 'Consider retraining or parameter tuning'
      }
    end
    
    # Stale model alerts
    stale_models = PredictiveAnalytic.where('last_prediction_at < ? OR last_prediction_at IS NULL', 7.days.ago)
    if stale_models.exists?
      alerts << {
        type: 'info',
        message: "#{stale_models.count} model(s) haven't been used recently",
        action: 'Consider archiving unused models'
      }
    end
    
    alerts
  end
  
  def parse_date_range(start_date, end_date)
    {
      start: start_date.present? ? Date.parse(start_date) : 30.days.ago.to_date,
      end: end_date.present? ? Date.parse(end_date) : Date.current
    }
  rescue Date::Error
    {
      start: 30.days.ago.to_date,
      end: Date.current
    }
  end
end