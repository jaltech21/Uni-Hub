class PredictiveAnalytic < ApplicationRecord
  belongs_to :campus, optional: true
  belongs_to :department, optional: true
  
  validates :prediction_type, presence: true, inclusion: {
    in: %w[student_success grade_prediction dropout_risk resource_demand course_completion 
           engagement_forecast performance_trend learning_pathway attendance_prediction]
  }
  validates :target_entity_type, presence: true
  validates :target_entity_id, presence: true
  validates :prediction_value, presence: true, numericality: true
  validates :confidence_score, presence: true, numericality: { in: 0.0..1.0 }
  validates :model_version, presence: true
  validates :prediction_date, presence: true
  
  scope :by_type, ->(type) { where(prediction_type: type) }
  scope :by_entity, ->(entity_type, entity_id) { where(target_entity_type: entity_type, target_entity_id: entity_id) }
  scope :high_confidence, -> { where('confidence_score >= 0.8') }
  scope :recent, -> { order(prediction_date: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(prediction_date: start_date..end_date) }
  scope :by_campus, ->(campus) { where(campus: campus) }
  scope :critical_predictions, -> { where('prediction_value < 0.3 OR prediction_value > 0.9') }
  
  # Student Success Prediction
  def self.predict_student_success(student, features = {})
    # Collect student performance features
    student_features = extract_student_features(student).merge(features)
    
    # Simple ML model (would be replaced with actual ML integration)
    prediction_score = calculate_success_probability(student_features)
    confidence = calculate_confidence(student_features)
    
    create!(
      prediction_type: 'student_success',
      target_entity_type: 'User',
      target_entity_id: student.id,
      prediction_value: prediction_score,
      confidence_score: confidence,
      model_version: 'v1.2.0',
      features: student_features,
      prediction_date: Time.current,
      department: student.department,
      campus: student.department&.campus
    )
  end
  
  def self.predict_grade_outcome(submission, assignment_features = {})
    # Analyze submission patterns and assignment complexity
    submission_features = extract_submission_features(submission).merge(assignment_features)
    
    predicted_grade = calculate_grade_prediction(submission_features)
    confidence = calculate_grade_confidence(submission_features)
    
    create!(
      prediction_type: 'grade_prediction',
      target_entity_type: 'Submission',
      target_entity_id: submission.id,
      prediction_value: predicted_grade,
      confidence_score: confidence,
      model_version: 'v1.1.0',
      features: submission_features,
      prediction_date: Time.current,
      department: submission.user.department,
      campus: submission.user.department&.campus
    )
  end
  
  def self.predict_dropout_risk(student)
    # Analyze multiple risk factors
    risk_features = extract_risk_features(student)
    
    dropout_probability = calculate_dropout_risk(risk_features)
    confidence = calculate_risk_confidence(risk_features)
    
    create!(
      prediction_type: 'dropout_risk',
      target_entity_type: 'User',
      target_entity_id: student.id,
      prediction_value: dropout_probability,
      confidence_score: confidence,
      model_version: 'v1.3.0',
      features: risk_features,
      prediction_date: Time.current,
      department: student.department,
      campus: student.department&.campus
    )
  end
  
  def self.predict_resource_demand(resource, forecast_period = 30.days)
    # Analyze historical usage patterns
    usage_features = extract_resource_features(resource, forecast_period)
    
    demand_forecast = calculate_demand_forecast(usage_features)
    confidence = calculate_demand_confidence(usage_features)
    
    create!(
      prediction_type: 'resource_demand',
      target_entity_type: resource.class.name,
      target_entity_id: resource.id,
      prediction_value: demand_forecast,
      confidence_score: confidence,
      model_version: 'v1.0.0',
      features: usage_features,
      prediction_date: Time.current,
      campus: resource.respond_to?(:campus) ? resource.campus : nil
    )
  end
  
  def self.predict_course_completion(student, course)
    # Analyze student progress and course characteristics
    completion_features = extract_completion_features(student, course)
    
    completion_probability = calculate_completion_probability(completion_features)
    confidence = calculate_completion_confidence(completion_features)
    
    create!(
      prediction_type: 'course_completion',
      target_entity_type: 'User',
      target_entity_id: student.id,
      prediction_value: completion_probability,
      confidence_score: confidence,
      model_version: 'v1.1.0',
      features: completion_features.merge(course_id: course.id),
      prediction_date: Time.current,
      department: student.department,
      campus: student.department&.campus
    )
  end
  
  # Batch prediction methods
  def self.batch_predict_student_success(students)
    predictions = []
    students.each do |student|
      prediction = predict_student_success(student)
      predictions << prediction
    end
    predictions
  end
  
  def self.batch_predict_dropout_risk(students)
    high_risk_students = []
    students.each do |student|
      prediction = predict_dropout_risk(student)
      high_risk_students << { student: student, prediction: prediction } if prediction.prediction_value > 0.7
    end
    high_risk_students
  end
  
  # Analytics and reporting
  def self.prediction_accuracy_report(prediction_type, period = 30.days)
    predictions = by_type(prediction_type)
                   .where('prediction_date >= ?', period.ago)
                   .where('prediction_date <= ?', 1.week.ago) # Only evaluate past predictions
    
    accurate_predictions = 0
    total_evaluated = 0
    
    predictions.each do |prediction|
      actual_outcome = get_actual_outcome(prediction)
      next if actual_outcome.nil?
      
      total_evaluated += 1
      prediction_correct = evaluate_prediction_accuracy(prediction, actual_outcome)
      accurate_predictions += 1 if prediction_correct
    end
    
    {
      prediction_type: prediction_type,
      total_predictions: predictions.count,
      evaluated_predictions: total_evaluated,
      accurate_predictions: accurate_predictions,
      accuracy_rate: total_evaluated > 0 ? (accurate_predictions.to_f / total_evaluated * 100).round(2) : 0,
      average_confidence: predictions.average(:confidence_score)&.round(3) || 0
    }
  end
  
  def self.get_critical_predictions(threshold = 0.7)
    {
      high_dropout_risk: by_type('dropout_risk').where('prediction_value >= ?', threshold).count,
      low_success_probability: by_type('student_success').where('prediction_value <= ?', 1 - threshold).count,
      failing_grade_predictions: by_type('grade_prediction').where('prediction_value <= 60').count,
      low_completion_risk: by_type('course_completion').where('prediction_value <= ?', 1 - threshold).count
    }
  end
  
  def self.intervention_recommendations(student)
    recent_predictions = where(target_entity_type: 'User', target_entity_id: student.id)
                          .where('prediction_date >= ?', 7.days.ago)
                          .order(:prediction_date)
    
    recommendations = []
    
    recent_predictions.each do |prediction|
      case prediction.prediction_type
      when 'dropout_risk'
        if prediction.prediction_value > 0.7
          recommendations << {
            type: 'urgent_intervention',
            priority: 'high',
            message: 'Student shows high dropout risk. Immediate academic counseling recommended.',
            confidence: prediction.confidence_score
          }
        end
      when 'student_success'
        if prediction.prediction_value < 0.3
          recommendations << {
            type: 'academic_support',
            priority: 'medium',
            message: 'Student may benefit from additional tutoring and study resources.',
            confidence: prediction.confidence_score
          }
        end
      when 'grade_prediction'
        if prediction.prediction_value < 60
          recommendations << {
            type: 'grade_improvement',
            priority: 'medium',
            message: 'Early intervention recommended to improve expected grade outcome.',
            confidence: prediction.confidence_score
          }
        end
      end
    end
    
    recommendations.sort_by { |r| [r[:priority] == 'high' ? 0 : 1, -r[:confidence]] }
  end
  
  # Model performance tracking
  def self.model_performance_summary(model_version = nil)
    scope = model_version ? where(model_version: model_version) : all
    
    {
      total_predictions: scope.count,
      prediction_types: scope.group(:prediction_type).count,
      average_confidence: scope.average(:confidence_score)&.round(3) || 0,
      high_confidence_predictions: scope.high_confidence.count,
      model_versions: scope.group(:model_version).count,
      recent_activity: scope.where('prediction_date >= ?', 7.days.ago).count
    }
  end
  
  private
  
  def self.extract_student_features(student)
    {
      avg_grade: student.submissions.where.not(grade: nil).average(:grade) || 0,
      submission_rate: calculate_submission_rate(student),
      attendance_rate: calculate_attendance_rate(student),
      engagement_score: calculate_engagement_score(student),
      days_since_enrollment: (Time.current - student.created_at) / 1.day,
      total_assignments: student.submissions.count,
      late_submissions: student.submissions.joins(:assignment).where('submissions.submitted_at > assignments.due_date').count
    }
  end
  
  def self.extract_submission_features(submission)
    assignment = submission.assignment
    user = submission.user
    
    {
      assignment_difficulty: calculate_assignment_difficulty(assignment),
      student_avg_grade: user.submissions.where.not(grade: nil).average(:grade) || 0,
      submission_timing: calculate_submission_timing(submission),
      content_length: submission.content&.length || 0,
      revision_count: submission.versions&.count || 0,
      time_spent: calculate_time_spent(submission)
    }
  end
  
  def self.extract_risk_features(student)
    {
      declining_grades: calculate_grade_trend(student) == 'declining',
      low_attendance: calculate_attendance_rate(student) < 0.7,
      missed_deadlines: calculate_missed_deadline_rate(student),
      low_engagement: calculate_engagement_score(student) < 0.5,
      support_requests: calculate_support_requests(student),
      social_isolation: calculate_social_isolation_score(student)
    }
  end
  
  def self.calculate_success_probability(features)
    # Simplified ML model - would be replaced with actual ML
    score = 0.0
    score += features[:avg_grade] / 100.0 * 0.3
    score += features[:submission_rate] * 0.2
    score += features[:attendance_rate] * 0.2
    score += features[:engagement_score] * 0.3
    
    # Normalize to 0-1 range
    [score, 1.0].min
  end
  
  def self.calculate_confidence(features)
    # Higher confidence with more data points
    data_points = features[:total_assignments] || 0
    base_confidence = [data_points / 20.0, 1.0].min
    
    # Adjust based on feature consistency
    consistency_score = calculate_feature_consistency(features)
    base_confidence * consistency_score
  end
  
  def self.calculate_submission_rate(student)
    assignments = Assignment.joins(:submissions).where(submissions: { user: student })
    total_assignments = Assignment.count
    return 0 if total_assignments == 0
    
    assignments.count.to_f / total_assignments
  end
  
  def self.calculate_attendance_rate(student)
    # Simplified calculation
    attended = student.attendance_records.count
    total_classes = Schedule.count
    return 0 if total_classes == 0
    
    attended.to_f / total_classes
  end
  
  def self.calculate_engagement_score(student)
    # Composite engagement score
    notes_created = student.notes.where('created_at >= ?', 30.days.ago).count
    collaborations = student.collaboration_sessions.where('created_at >= ?', 30.days.ago).count
    
    # Normalize to 0-1 scale
    [(notes_created * 0.1 + collaborations * 0.2), 1.0].min
  end
end
