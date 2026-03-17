class PredictiveAnalyticsService
  include ActiveModel::Model
  
  # Machine learning model for predicting at-risk students
  class << self
    def predict_at_risk_students(students = nil)
      students ||= User.where(role: 'student').includes(:submissions, :attendance_records, :notes)
      predictions = {}
      
      students.each do |student|
        predictions[student.id] = predict_student_risk(student)
      end
      
      predictions
    end
    
    def predict_student_risk(student)
      features = extract_student_features(student)
      risk_score = calculate_risk_score(features)
      
      {
        risk_score: risk_score,
        risk_level: determine_risk_level(risk_score),
        risk_factors: identify_risk_factors(features),
        predicted_outcome: predict_outcome(risk_score, features),
        suggested_interventions: suggest_interventions(risk_score, features),
        evidence: compile_evidence(student, features),
        metrics: features,
        confidence: calculate_confidence(features)
      }
    end
    
    def predict_grade_outcome(student, assignment = nil)
      if assignment
        predict_assignment_grade(student, assignment)
      else
        predict_overall_grade(student)
      end
    end
    
    def predict_assignment_grade(student, assignment)
      features = extract_assignment_features(student, assignment)
      predicted_grade = calculate_predicted_grade(features)
      
      {
        predicted_grade: predicted_grade,
        confidence: calculate_grade_confidence(features),
        factors: identify_grade_factors(features),
        recommendations: generate_grade_recommendations(predicted_grade, features)
      }
    end
    
    def predict_overall_grade(student)
      historical_data = get_historical_performance(student)
      current_trends = analyze_current_trends(student)
      
      predicted_gpa = calculate_predicted_gpa(historical_data, current_trends)
      
      {
        predicted_gpa: predicted_gpa,
        confidence: calculate_gpa_confidence(historical_data, current_trends),
        trend_direction: determine_trend_direction(current_trends),
        contributing_factors: identify_gpa_factors(historical_data, current_trends)
      }
    end
    
    def predict_engagement_trends(student)
      engagement_history = get_engagement_history(student)
      engagement_score = calculate_engagement_score(student)
      
      predicted_trend = analyze_engagement_trend(engagement_history)
      
      {
        current_engagement: engagement_score,
        predicted_trend: predicted_trend,
        engagement_factors: identify_engagement_factors(student),
        intervention_recommendations: suggest_engagement_interventions(engagement_score, predicted_trend)
      }
    end
    
    def predict_dropout_risk(student)
      dropout_features = extract_dropout_features(student)
      dropout_probability = calculate_dropout_probability(dropout_features)
      
      {
        dropout_probability: dropout_probability,
        risk_level: determine_dropout_risk_level(dropout_probability),
        warning_signs: identify_dropout_warning_signs(dropout_features),
        retention_strategies: suggest_retention_strategies(dropout_features)
      }
    end
    
    private
    
    def extract_student_features(student)
      time_range = 90.days.ago..Time.current
      
      # Academic performance features
      submissions = student.submissions.joins(:assignment).where(assignments: { created_at: time_range })
      grades = submissions.where.not(grade: nil).pluck(:grade)
      
      # Attendance features
      attendance_records = student.attendance_records.where(created_at: time_range)
      total_classes = attendance_records.count
      present_count = attendance_records.where(status: ['present', 'late']).count
      
      # Engagement features
      notes_count = student.notes.where(updated_at: time_range).count
      login_frequency = calculate_login_frequency(student, time_range)
      
      # Assignment submission patterns
      on_time_submissions = submissions.joins(:assignment)
                                     .where('submissions.submitted_at <= assignments.due_date')
                                     .count
      late_submissions = submissions.joins(:assignment)
                                   .where('submissions.submitted_at > assignments.due_date')
                                   .count
      
      {
        # Performance metrics
        average_grade: grades.any? ? grades.sum / grades.count.to_f : nil,
        grade_trend: calculate_grade_trend(grades),
        grade_variance: calculate_variance(grades),
        
        # Attendance metrics
        attendance_rate: total_classes > 0 ? present_count / total_classes.to_f : nil,
        attendance_consistency: calculate_attendance_consistency(attendance_records),
        
        # Engagement metrics
        notes_activity: notes_count,
        login_frequency: login_frequency,
        engagement_score: calculate_engagement_score(student),
        
        # Submission patterns
        submission_rate: calculate_submission_rate(student),
        on_time_rate: submissions.count > 0 ? on_time_submissions / submissions.count.to_f : nil,
        late_submission_rate: submissions.count > 0 ? late_submissions / submissions.count.to_f : nil,
        
        # Time-based patterns
        study_consistency: calculate_study_consistency(student),
        workload_management: assess_workload_management(student),
        
        # Comparative metrics
        peer_comparison: calculate_peer_comparison(student),
        department_ranking: calculate_department_ranking(student)
      }
    end
    
    def calculate_risk_score(features)
      # Weighted risk calculation based on multiple factors
      risk_components = {}
      
      # Academic performance risk (40% weight)
      if features[:average_grade]
        grade_risk = case features[:average_grade]
                    when 0..59 then 0.9
                    when 60..69 then 0.6
                    when 70..79 then 0.3
                    when 80..89 then 0.1
                    else 0.05
                    end
        risk_components[:academic] = grade_risk * 0.4
      end
      
      # Attendance risk (25% weight)
      if features[:attendance_rate]
        attendance_risk = case features[:attendance_rate]
                         when 0..0.6 then 0.8
                         when 0.6..0.75 then 0.5
                         when 0.75..0.85 then 0.2
                         else 0.05
                         end
        risk_components[:attendance] = attendance_risk * 0.25
      end
      
      # Engagement risk (20% weight)
      engagement_risk = case features[:engagement_score]
                       when 0..0.3 then 0.7
                       when 0.3..0.5 then 0.4
                       when 0.5..0.7 then 0.2
                       else 0.05
                       end
      risk_components[:engagement] = engagement_risk * 0.2
      
      # Submission pattern risk (15% weight)
      if features[:on_time_rate]
        submission_risk = case features[:on_time_rate]
                         when 0..0.5 then 0.6
                         when 0.5..0.75 then 0.3
                         when 0.75..0.9 then 0.1
                         else 0.02
                         end
        risk_components[:submissions] = submission_risk * 0.15
      end
      
      # Calculate overall risk score
      total_risk = risk_components.values.sum
      [total_risk, 1.0].min
    end
    
    def determine_risk_level(risk_score)
      case risk_score
      when 0.8..1.0 then 'critical'
      when 0.6..0.79 then 'high'
      when 0.4..0.59 then 'medium'
      when 0.2..0.39 then 'low'
      else 'minimal'
      end
    end
    
    def identify_risk_factors(features)
      factors = []
      
      factors << 'low_grades' if features[:average_grade] && features[:average_grade] < 70
      factors << 'declining_performance' if features[:grade_trend] && features[:grade_trend] < -5
      factors << 'poor_attendance' if features[:attendance_rate] && features[:attendance_rate] < 0.75
      factors << 'low_engagement' if features[:engagement_score] < 0.4
      factors << 'frequent_late_submissions' if features[:late_submission_rate] && features[:late_submission_rate] > 0.3
      factors << 'inconsistent_study_patterns' if features[:study_consistency] && features[:study_consistency] < 0.5
      factors << 'below_peer_average' if features[:peer_comparison] && features[:peer_comparison] < -0.2
      
      factors
    end
    
    def predict_outcome(risk_score, features)
      if risk_score > 0.8
        'likely_to_fail'
      elsif risk_score > 0.6
        'at_risk_of_poor_performance'
      elsif risk_score > 0.4
        'needs_additional_support'
      else
        'likely_to_succeed'
      end
    end
    
    def suggest_interventions(risk_score, features)
      interventions = []
      
      if risk_score > 0.7
        interventions << 'immediate_academic_counseling'
        interventions << 'intensive_tutoring'
        interventions << 'reduced_course_load_consideration'
      end
      
      if features[:attendance_rate] && features[:attendance_rate] < 0.75
        interventions << 'attendance_intervention'
        interventions << 'flexible_learning_options'
      end
      
      if features[:engagement_score] < 0.4
        interventions << 'engagement_strategies'
        interventions << 'learning_style_assessment'
      end
      
      if features[:late_submission_rate] && features[:late_submission_rate] > 0.3
        interventions << 'time_management_training'
        interventions << 'assignment_planning_support'
      end
      
      interventions
    end
    
    def compile_evidence(student, features)
      evidence = []
      
      if features[:average_grade] && features[:average_grade] < 70
        evidence << "Average grade: #{features[:average_grade].round(1)}% (below passing threshold)"
      end
      
      if features[:attendance_rate] && features[:attendance_rate] < 0.8
        evidence << "Attendance rate: #{(features[:attendance_rate] * 100).round(1)}% (below recommended 80%)"
      end
      
      if features[:late_submission_rate] && features[:late_submission_rate] > 0.2
        evidence << "Late submission rate: #{(features[:late_submission_rate] * 100).round(1)}% (above acceptable threshold)"
      end
      
      if features[:engagement_score] < 0.5
        evidence << "Low engagement score: #{(features[:engagement_score] * 100).round(1)}%"
      end
      
      evidence
    end
    
    def calculate_confidence(features)
      # Confidence based on data completeness and recency
      confidence_factors = []
      
      # Data availability
      confidence_factors << 0.8 if features[:average_grade]
      confidence_factors << 0.7 if features[:attendance_rate]
      confidence_factors << 0.6 if features[:engagement_score]
      confidence_factors << 0.5 if features[:submission_rate]
      
      # Data quality indicators
      confidence_factors << 0.3 if features[:grade_variance] && features[:grade_variance] < 100
      confidence_factors << 0.2 if features[:attendance_consistency] && features[:attendance_consistency] > 0.5
      
      confidence_factors.any? ? confidence_factors.sum / confidence_factors.count : 0.5
    end
    
    # Helper methods for feature extraction
    def calculate_grade_trend(grades)
      return 0 if grades.count < 3
      
      # Simple linear trend calculation
      recent_grades = grades.last(5)
      earlier_grades = grades.first(5)
      
      recent_avg = recent_grades.sum / recent_grades.count.to_f
      earlier_avg = earlier_grades.sum / earlier_grades.count.to_f
      
      recent_avg - earlier_avg
    end
    
    def calculate_variance(values)
      return 0 if values.empty?
      
      mean = values.sum / values.count.to_f
      variance = values.map { |v| (v - mean) ** 2 }.sum / values.count.to_f
      Math.sqrt(variance)
    end
    
    def calculate_attendance_consistency(attendance_records)
      return 0.5 if attendance_records.empty?
      
      # Calculate consistency based on attendance patterns
      daily_attendance = attendance_records.group_by(&:created_at)
      present_days = daily_attendance.count { |_, records| records.any? { |r| r.status.in?(['present', 'late']) } }
      
      present_days / daily_attendance.count.to_f
    end
    
    def calculate_login_frequency(student, time_range)
      # This would typically check login logs
      # For now, using note activity as a proxy
      student.notes.where(updated_at: time_range).count / time_range.to_i.days.to_f
    end
    
    def calculate_engagement_score(student)
      time_range = 30.days.ago..Time.current
      
      # Weighted engagement calculation
      notes_weight = 0.3
      attendance_weight = 0.4
      submission_weight = 0.3
      
      notes_score = [student.notes.where(updated_at: time_range).count / 10.0, 1.0].min
      
      attendance_records = student.attendance_records.where(created_at: time_range)
      attendance_score = if attendance_records.any?
                          attendance_records.where(status: ['present', 'late']).count / attendance_records.count.to_f
                        else
                          0.5
                        end
      
      submissions = student.submissions.joins(:assignment).where(assignments: { created_at: time_range })
      submission_score = if submissions.any?
                          submissions.where.not(submitted_at: nil).count / submissions.count.to_f
                        else
                          0.5
                        end
      
      (notes_score * notes_weight) + (attendance_score * attendance_weight) + (submission_score * submission_weight)
    end
    
    def calculate_submission_rate(student)
      time_range = 90.days.ago..Time.current
      
      # Get assignments student should have submitted
      student_schedules = student.schedules
      total_assignments = Assignment.joins(:user)
                                   .where(users: { schedules: student_schedules })
                                   .where(created_at: time_range)
                                   .count
      
      submitted_assignments = student.submissions
                                    .joins(:assignment)
                                    .where(assignments: { created_at: time_range })
                                    .count
      
      return 0.5 if total_assignments.zero?
      
      submitted_assignments / total_assignments.to_f
    end
    
    def calculate_study_consistency(student)
      # Based on note-taking and assignment submission patterns
      time_range = 30.days.ago..Time.current
      
      daily_activity = {}
      
      # Note-taking activity
      student.notes.where(updated_at: time_range).find_each do |note|
        date = note.updated_at.to_date
        daily_activity[date] ||= 0
        daily_activity[date] += 1
      end
      
      # Submission activity
      student.submissions.where(created_at: time_range).find_each do |submission|
        date = submission.created_at.to_date
        daily_activity[date] ||= 0
        daily_activity[date] += 2 # Weight submissions higher
      end
      
      return 0.5 if daily_activity.empty?
      
      # Calculate consistency (lower variance = higher consistency)
      activities = daily_activity.values
      mean = activities.sum / activities.count.to_f
      variance = activities.map { |a| (a - mean) ** 2 }.sum / activities.count.to_f
      
      # Normalize to 0-1 scale (lower variance = higher consistency score)
      [1.0 - (Math.sqrt(variance) / 10.0), 0.0].max
    end
    
    def assess_workload_management(student)
      # Assess based on submission timing and quality
      time_range = 60.days.ago..Time.current
      
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { created_at: time_range })
      
      return 0.5 if submissions.empty?
      
      on_time_count = submissions.where('submitted_at <= assignments.due_date').count
      total_count = submissions.count
      
      on_time_count / total_count.to_f
    end
    
    def calculate_peer_comparison(student)
      # Compare student performance to department peers
      return 0 unless student.department
      
      peers = User.where(role: 'student', department: student.department)
                  .where.not(id: student.id)
      
      return 0 if peers.empty?
      
      student_avg = calculate_student_average_grade(student)
      peer_averages = peers.map { |peer| calculate_student_average_grade(peer) }.compact
      
      return 0 if peer_averages.empty? || student_avg.nil?
      
      peer_mean = peer_averages.sum / peer_averages.count.to_f
      
      (student_avg - peer_mean) / peer_mean
    end
    
    def calculate_department_ranking(student)
      # Simple ranking within department
      return 0.5 unless student.department
      
      peers = User.where(role: 'student', department: student.department)
      peer_grades = peers.map { |peer| [peer.id, calculate_student_average_grade(peer)] }
                         .select { |_, grade| grade }
                         .sort_by { |_, grade| -grade }
      
      return 0.5 if peer_grades.empty?
      
      student_position = peer_grades.find_index { |id, _| id == student.id }
      return 0.5 unless student_position
      
      1.0 - (student_position / peer_grades.count.to_f)
    end
    
    def calculate_student_average_grade(student)
      time_range = 90.days.ago..Time.current
      grades = student.submissions.joins(:assignment)
                     .where(assignments: { created_at: time_range })
                     .where.not(grade: nil)
                     .pluck(:grade)
      
      grades.any? ? grades.sum / grades.count.to_f : nil
    end
    
    # Additional methods for other prediction types would go here...
    def extract_assignment_features(student, assignment)
      {
        student_avg_grade: calculate_student_average_grade(student),
        assignment_difficulty: estimate_assignment_difficulty(assignment),
        time_to_deadline: (assignment.due_date - Time.current) / 1.day,
        student_workload: assess_current_workload(student),
        subject_performance: calculate_subject_performance(student, assignment.schedule)
      }
    end
    
    def calculate_predicted_grade(features)
      base_grade = features[:student_avg_grade] || 75
      
      # Adjust based on assignment difficulty
      difficulty_adjustment = case features[:assignment_difficulty]
                             when 'easy' then 5
                             when 'hard' then -10
                             else 0
                             end
      
      # Adjust based on time pressure
      time_adjustment = if features[:time_to_deadline] < 1
                         -15 # Last minute submission
                       elsif features[:time_to_deadline] > 7
                         5 # Plenty of time
                       else
                         0
                       end
      
      # Adjust based on workload
      workload_adjustment = case features[:student_workload]
                           when 'high' then -5
                           when 'low' then 3
                           else 0
                           end
      
      predicted = base_grade + difficulty_adjustment + time_adjustment + workload_adjustment
      [predicted, 100].min
    end
    
    def estimate_assignment_difficulty(assignment)
      # This would analyze assignment content, length, requirements
      # For now, return a simple estimation
      case assignment.points_possible
      when 0..50 then 'easy'
      when 51..80 then 'medium'
      else 'hard'
      end
    end
    
    def assess_current_workload(student)
      upcoming_assignments = Assignment.joins(:schedule)
                                      .joins('JOIN schedules_users ON schedules.id = schedules_users.schedule_id')
                                      .where('schedules_users.user_id = ?', student.id)
                                      .where('due_date > ? AND due_date < ?', Time.current, 7.days.from_now)
                                      .count
      
      case upcoming_assignments
      when 0..2 then 'low'
      when 3..5 then 'medium'
      else 'high'
      end
    end
    
    def calculate_subject_performance(student, schedule)
      return 75 unless schedule
      
      subject_grades = student.submissions.joins(:assignment)
                             .where(assignments: { schedule: schedule })
                             .where.not(grade: nil)
                             .pluck(:grade)
      
      subject_grades.any? ? subject_grades.sum / subject_grades.count.to_f : 75
    end
    
    # Additional helper methods for other prediction features...
    def get_historical_performance(student)
      {
        grades_by_month: calculate_monthly_grades(student),
        submission_patterns: analyze_submission_patterns(student),
        engagement_history: get_engagement_history(student)
      }
    end
    
    def analyze_current_trends(student)
      recent_grades = student.submissions.joins(:assignment)
                            .where('assignments.created_at >= ?', 30.days.ago)
                            .where.not(grade: nil)
                            .pluck(:grade)
      
      {
        recent_average: recent_grades.any? ? recent_grades.sum / recent_grades.count.to_f : nil,
        grade_trend: calculate_grade_trend(recent_grades),
        submission_trend: analyze_recent_submission_trend(student)
      }
    end
    
    def calculate_monthly_grades(student)
      # Group grades by month for trend analysis
      student.submissions.joins(:assignment)
            .where.not(grade: nil)
            .group_by { |s| s.assignment.created_at.beginning_of_month }
            .transform_values { |submissions| submissions.map(&:grade).sum / submissions.count.to_f }
    end
    
    def analyze_submission_patterns(student)
      submissions = student.submissions.joins(:assignment).includes(:assignment)
      
      {
        average_days_early: calculate_average_submission_timing(submissions),
        consistency_score: calculate_submission_consistency(submissions),
        quality_trend: analyze_submission_quality_trend(submissions)
      }
    end
    
    def get_engagement_history(student)
      30.times.map do |days_ago|
        date = days_ago.days.ago.to_date
        {
          date: date,
          notes_created: student.notes.where(created_at: date.beginning_of_day..date.end_of_day).count,
          login_activity: 1 # Placeholder - would track actual logins
        }
      end
    end
    
    def calculate_average_submission_timing(submissions)
      timing_data = submissions.map do |submission|
        next unless submission.submitted_at && submission.assignment.due_date
        
        (submission.assignment.due_date.to_date - submission.submitted_at.to_date).to_i
      end.compact
      
      timing_data.any? ? timing_data.sum / timing_data.count.to_f : 0
    end
    
    def calculate_submission_consistency(submissions)
      return 0.5 if submissions.count < 3
      
      submission_gaps = submissions.sort_by(&:created_at)
                                  .each_cons(2)
                                  .map { |a, b| (b.created_at - a.created_at) / 1.day }
      
      return 0.5 if submission_gaps.empty?
      
      mean_gap = submission_gaps.sum / submission_gaps.count.to_f
      variance = submission_gaps.map { |gap| (gap - mean_gap) ** 2 }.sum / submission_gaps.count.to_f
      
      # Lower variance = higher consistency
      [1.0 - (Math.sqrt(variance) / 7.0), 0.0].max
    end
    
    def analyze_submission_quality_trend(submissions)
      return 'stable' if submissions.count < 3
      
      graded_submissions = submissions.where.not(grade: nil).order(:created_at)
      return 'stable' if graded_submissions.count < 3
      
      grades = graded_submissions.pluck(:grade)
      recent_avg = grades.last(3).sum / 3.0
      earlier_avg = grades.first(3).sum / 3.0
      
      if recent_avg > earlier_avg + 5
        'improving'
      elsif recent_avg < earlier_avg - 5
        'declining'
      else
        'stable'
      end
    end
    
    def analyze_recent_submission_trend(student)
      recent_submissions = student.submissions.where('created_at >= ?', 14.days.ago)
      older_submissions = student.submissions.where(created_at: 30.days.ago..14.days.ago)
      
      recent_count = recent_submissions.count
      older_count = older_submissions.count
      
      return 'stable' if recent_count == 0 && older_count == 0
      
      if recent_count > older_count
        'increasing'
      elsif recent_count < older_count
        'decreasing'  
      else
        'stable'
      end
    end
  end
end