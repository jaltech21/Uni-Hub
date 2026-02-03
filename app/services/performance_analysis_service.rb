class PerformanceAnalysisService
  include ActiveModel::Model
  
  class << self
    def analyze_trends(student, time_range = 90.days.ago..Time.current)
      performance_data = extract_performance_data(student, time_range)
      
      {
        current_performance: performance_data[:current_average],
        trend_direction: calculate_trend_direction(performance_data[:grades_over_time]),
        declining_trend: detect_declining_trend(performance_data[:grades_over_time]),
        improvement_areas: identify_improvement_areas(student, performance_data),
        strengths: identify_strengths(student, performance_data),
        confidence: calculate_analysis_confidence(performance_data),
        evidence: compile_performance_evidence(performance_data),
        recommendations: generate_performance_recommendations(performance_data)
      }
    end
    
    def analyze_subject_performance(student, schedule = nil)
      if schedule
        analyze_single_subject(student, schedule)
      else
        analyze_all_subjects(student)
      end
    end
    
    def compare_peer_performance(student)
      return {} unless student.department
      
      peers = User.where(role: 'student', department: student.department)
                  .where.not(id: student.id)
      
      student_metrics = calculate_student_metrics(student)
      peer_metrics = peers.map { |peer| calculate_student_metrics(peer) }.compact
      
      {
        student_percentile: calculate_percentile(student_metrics[:average_grade], peer_metrics.map { |m| m[:average_grade] }),
        above_average_areas: identify_above_average_areas(student_metrics, peer_metrics),
        below_average_areas: identify_below_average_areas(student_metrics, peer_metrics),
        peer_comparison_insights: generate_peer_insights(student_metrics, peer_metrics)
      }
    end
    
    def predict_final_grades(student)
      current_performance = get_current_performance(student)
      historical_patterns = analyze_historical_patterns(student)
      
      predictions = {}
      
      student.schedules.each do |schedule|
        subject_data = get_subject_performance_data(student, schedule)
        predicted_grade = calculate_predicted_final_grade(subject_data, historical_patterns)
        
        predictions[schedule.id] = {
          subject: schedule.title,
          current_grade: subject_data[:current_average],
          predicted_final: predicted_grade,
          confidence: calculate_prediction_confidence(subject_data),
          factors: identify_prediction_factors(subject_data)
        }
      end
      
      predictions
    end
    
    def analyze_learning_velocity(student)
      performance_data = get_time_series_performance(student)
      
      {
        learning_velocity: calculate_learning_velocity(performance_data),
        acceleration: calculate_learning_acceleration(performance_data),
        plateau_detection: detect_learning_plateaus(performance_data),
        breakthrough_prediction: predict_breakthrough_potential(performance_data)
      }
    end
    
    def identify_performance_patterns(student)
      patterns = {}
      
      # Weekly performance patterns
      patterns[:weekly] = analyze_weekly_patterns(student)
      
      # Assignment type performance
      patterns[:assignment_types] = analyze_assignment_type_performance(student)
      
      # Time-of-submission patterns
      patterns[:submission_timing] = analyze_submission_timing_patterns(student)
      
      # Difficulty level patterns
      patterns[:difficulty_response] = analyze_difficulty_response_patterns(student)
      
      patterns
    end
    
    private
    
    def extract_performance_data(student, time_range)
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { created_at: time_range })
                          .where.not(grade: nil)
                          .includes(:assignment)
                          .order(:created_at)
      
      grades = submissions.pluck(:grade)
      
      {
        total_submissions: submissions.count,
        grades: grades,
        current_average: grades.any? ? grades.sum / grades.count.to_f : nil,
        grades_over_time: submissions.map { |s| { date: s.created_at.to_date, grade: s.grade } },
        subject_breakdown: analyze_subject_breakdown(submissions),
        assignment_types: analyze_assignment_types(submissions)
      }
    end
    
    def calculate_trend_direction(grades_over_time)
      return 'insufficient_data' if grades_over_time.count < 3
      
      # Simple linear regression to determine trend
      n = grades_over_time.count
      sum_x = (0...n).sum
      sum_y = grades_over_time.sum { |g| g[:grade] }
      sum_xy = grades_over_time.each_with_index.sum { |g, i| g[:grade] * i }
      sum_x2 = (0...n).sum { |i| i * i }
      
      slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x).to_f
      
      case slope
      when Float::INFINITY, -Float::INFINITY, Float::NAN
        'stable'
      when -Float::INFINITY..-2
        'steep_decline'
      when -2..-0.5
        'declining'
      when -0.5..0.5
        'stable'
      when 0.5..2
        'improving'
      else
        'steep_improvement'
      end
    end
    
    def detect_declining_trend(grades_over_time)
      return false if grades_over_time.count < 4
      
      # Look for consistent decline over recent submissions
      recent_grades = grades_over_time.last(4).map { |g| g[:grade] }
      
      # Check if each grade is lower than the previous (with some tolerance)
      declining_count = 0
      recent_grades.each_cons(2) do |prev, curr|
        declining_count += 1 if curr < prev - 2 # Allow for small fluctuations
      end
      
      declining_count >= 2 # At least 2 out of 3 consecutive declines
    end
    
    def identify_improvement_areas(student, performance_data)
      areas = []
      
      # Subject-specific improvements
      performance_data[:subject_breakdown].each do |subject, data|
        if data[:average] < 75
          areas << {
            area: "#{subject} performance",
            current_level: data[:average],
            priority: data[:average] < 60 ? 'high' : 'medium',
            specific_issues: identify_subject_issues(student, subject)
          }
        end
      end
      
      # Assignment type improvements
      performance_data[:assignment_types].each do |type, data|
        if data[:average] < performance_data[:current_average] - 10
          areas << {
            area: "#{type} assignments",
            current_level: data[:average],
            priority: 'medium',
            specific_issues: ["Underperforming in #{type} compared to overall average"]
          }
        end
      end
      
      areas
    end
    
    def identify_strengths(student, performance_data)
      strengths = []
      
      # High-performing subjects
      performance_data[:subject_breakdown].each do |subject, data|
        if data[:average] > 85
          strengths << {
            area: "#{subject} excellence",
            level: data[:average],
            consistency: data[:consistency_score] || 0.5
          }
        end
      end
      
      # Strong assignment types
      performance_data[:assignment_types].each do |type, data|
        if data[:average] > performance_data[:current_average] + 10
          strengths << {
            area: "#{type} assignments",
            level: data[:average],
            advantage: data[:average] - performance_data[:current_average]
          }
        end
      end
      
      strengths
    end
    
    def analyze_subject_breakdown(submissions)
      breakdown = {}
      
      submissions.group_by { |s| s.assignment.schedule.title }.each do |subject, subject_submissions|
        grades = subject_submissions.map(&:grade)
        
        breakdown[subject] = {
          count: grades.count,
          average: grades.sum / grades.count.to_f,
          highest: grades.max,
          lowest: grades.min,
          consistency_score: calculate_consistency_score(grades)
        }
      end
      
      breakdown
    end
    
    def analyze_assignment_types(submissions)
      types = {}
      
      # Group by assignment type (if available) or use points_possible as proxy
      submissions.group_by { |s| categorize_assignment(s.assignment) }.each do |type, type_submissions|
        grades = type_submissions.map(&:grade)
        
        types[type] = {
          count: grades.count,
          average: grades.sum / grades.count.to_f,
          trend: calculate_type_trend(type_submissions)
        }
      end
      
      types
    end
    
    def categorize_assignment(assignment)
      # Simple categorization based on points
      case assignment.points_possible
      when 0..25
        'quiz'
      when 26..75
        'assignment'
      when 76..150
        'project'
      else
        'major_project'
      end
    end
    
    def calculate_consistency_score(grades)
      return 0.5 if grades.count < 2
      
      mean = grades.sum / grades.count.to_f
      variance = grades.map { |g| (g - mean) ** 2 }.sum / grades.count.to_f
      standard_deviation = Math.sqrt(variance)
      
      # Normalize consistency score (lower std dev = higher consistency)
      [1.0 - (standard_deviation / 25.0), 0.0].max
    end
    
    def calculate_type_trend(submissions)
      return 'stable' if submissions.count < 3
      
      sorted_submissions = submissions.sort_by(&:created_at)
      grades = sorted_submissions.map(&:grade)
      
      first_half = grades.first(grades.count / 2)
      second_half = grades.last(grades.count / 2)
      
      return 'stable' if first_half.empty? || second_half.empty?
      
      first_avg = first_half.sum / first_half.count.to_f
      second_avg = second_half.sum / second_half.count.to_f
      
      difference = second_avg - first_avg
      
      case difference
      when -Float::INFINITY..-5
        'declining'
      when -5..5
        'stable'
      else
        'improving'
      end
    end
    
    def analyze_single_subject(student, schedule)
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { schedule: schedule })
                          .where.not(grade: nil)
                          .includes(:assignment)
                          .order(:created_at)
      
      return { error: 'insufficient_data' } if submissions.count < 2
      
      grades = submissions.pluck(:grade)
      
      {
        subject: schedule.title,
        total_assignments: submissions.count,
        current_average: grades.sum / grades.count.to_f,
        trend: calculate_subject_trend(submissions),
        strengths: identify_subject_strengths(submissions),
        challenges: identify_subject_challenges(submissions),
        improvement_suggestions: generate_subject_recommendations(submissions)
      }
    end
    
    def analyze_all_subjects(student)
      subjects = {}
      
      student.schedules.each do |schedule|
        subject_analysis = analyze_single_subject(student, schedule)
        subjects[schedule.id] = subject_analysis unless subject_analysis[:error]
      end
      
      subjects
    end
    
    def calculate_student_metrics(student)
      time_range = 90.days.ago..Time.current
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { created_at: time_range })
                          .where.not(grade: nil)
      
      return nil if submissions.empty?
      
      grades = submissions.pluck(:grade)
      attendance_records = student.attendance_records.where(created_at: time_range)
      
      {
        average_grade: grades.sum / grades.count.to_f,
        grade_consistency: calculate_consistency_score(grades),
        attendance_rate: calculate_attendance_rate(attendance_records),
        submission_rate: calculate_submission_rate(student, time_range),
        engagement_score: calculate_engagement_score(student, time_range)
      }
    end
    
    def calculate_percentile(value, peer_values)
      return 50 if peer_values.empty? || value.nil?
      
      valid_values = peer_values.compact
      return 50 if valid_values.empty?
      
      below_count = valid_values.count { |v| v < value }
      (below_count / valid_values.count.to_f * 100).round
    end
    
    def identify_above_average_areas(student_metrics, peer_metrics)
      areas = []
      
      peer_averages = calculate_peer_averages(peer_metrics)
      
      student_metrics.each do |metric, value|
        next unless value && peer_averages[metric]
        
        if value > peer_averages[metric]
          percentile = calculate_percentile(value, peer_metrics.map { |m| m[metric] })
          areas << {
            metric: metric,
            student_value: value,
            peer_average: peer_averages[metric],
            percentile: percentile,
            advantage: value - peer_averages[metric]
          }
        end
      end
      
      areas
    end
    
    def identify_below_average_areas(student_metrics, peer_metrics)
      areas = []
      
      peer_averages = calculate_peer_averages(peer_metrics)
      
      student_metrics.each do |metric, value|
        next unless value && peer_averages[metric]
        
        if value < peer_averages[metric]
          percentile = calculate_percentile(value, peer_metrics.map { |m| m[metric] })
          areas << {
            metric: metric,
            student_value: value,
            peer_average: peer_averages[metric],
            percentile: percentile,
            gap: peer_averages[metric] - value
          }
        end
      end
      
      areas
    end
    
    def calculate_peer_averages(peer_metrics)
      return {} if peer_metrics.empty?
      
      averages = {}
      
      # Get all unique metrics
      all_metrics = peer_metrics.flat_map(&:keys).uniq
      
      all_metrics.each do |metric|
        values = peer_metrics.map { |m| m[metric] }.compact
        averages[metric] = values.any? ? values.sum / values.count.to_f : nil
      end
      
      averages
    end
    
    def calculate_attendance_rate(attendance_records)
      return 0.8 if attendance_records.empty? # Default assumption
      
      present_count = attendance_records.where(status: ['present', 'late']).count
      present_count / attendance_records.count.to_f
    end
    
    def calculate_submission_rate(student, time_range)
      # Calculate based on assignments student should have submitted
      student_schedules = student.schedules
      return 0.8 if student_schedules.empty?
      
      total_assignments = Assignment.joins(:schedule)
                                   .where(schedule: student_schedules)
                                   .where(created_at: time_range)
                                   .count
      
      return 0.8 if total_assignments.zero?
      
      submitted_assignments = student.submissions.joins(:assignment)
                                    .where(assignments: { created_at: time_range })
                                    .count
      
      submitted_assignments / total_assignments.to_f
    end
    
    def calculate_engagement_score(student, time_range)
      # Simple engagement calculation
      notes_count = student.notes.where(updated_at: time_range).count
      max_notes = 30 # Reasonable maximum for the time period
      
      notes_score = [notes_count / max_notes.to_f, 1.0].min
      
      # Add other engagement factors as available
      notes_score
    end
    
    # Additional helper methods for other analysis functions...
    def get_current_performance(student)
      recent_submissions = student.submissions.joins(:assignment)
                                 .where('assignments.created_at >= ?', 30.days.ago)
                                 .where.not(grade: nil)
      
      return { average: nil, count: 0 } if recent_submissions.empty?
      
      grades = recent_submissions.pluck(:grade)
      {
        average: grades.sum / grades.count.to_f,
        count: grades.count,
        trend: calculate_recent_trend(grades)
      }
    end
    
    def analyze_historical_patterns(student)
      # Analyze patterns over longer time period
      all_submissions = student.submissions.joins(:assignment)
                              .where.not(grade: nil)
                              .includes(:assignment)
                              .order(:created_at)
      
      return {} if all_submissions.count < 5
      
      {
        overall_trend: calculate_overall_trend(all_submissions),
        seasonal_patterns: detect_seasonal_patterns(all_submissions),
        improvement_rate: calculate_improvement_rate(all_submissions)
      }
    end
    
    def get_subject_performance_data(student, schedule)
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { schedule: schedule })
                          .where.not(grade: nil)
                          .order(:created_at)
      
      return { current_average: nil, trend: 'insufficient_data' } if submissions.empty?
      
      grades = submissions.pluck(:grade)
      
      {
        current_average: grades.sum / grades.count.to_f,
        trend: calculate_subject_trend(submissions),
        consistency: calculate_consistency_score(grades),
        recent_performance: analyze_recent_subject_performance(submissions)
      }
    end
    
    def calculate_predicted_final_grade(subject_data, historical_patterns)
      return subject_data[:current_average] unless subject_data[:current_average]
      
      base_grade = subject_data[:current_average]
      
      # Adjust based on trend
      trend_adjustment = case subject_data[:trend]
                        when 'improving' then 5
                        when 'declining' then -5
                        else 0
                        end
      
      # Adjust based on historical improvement patterns
      historical_adjustment = if historical_patterns[:improvement_rate] && historical_patterns[:improvement_rate] > 0
                               historical_patterns[:improvement_rate] * 2
                             else
                               0
                             end
      
      predicted = base_grade + trend_adjustment + historical_adjustment
      [predicted, 100].min
    end
    
    def calculate_prediction_confidence(subject_data)
      confidence_factors = []
      
      # More data = higher confidence
      confidence_factors << 0.3 if subject_data[:current_average]
      confidence_factors << 0.2 if subject_data[:trend] != 'insufficient_data'
      confidence_factors << 0.3 if subject_data[:consistency] && subject_data[:consistency] > 0.5
      confidence_factors << 0.2 if subject_data[:recent_performance]
      
      confidence_factors.sum
    end
    
    def identify_prediction_factors(subject_data)
      factors = []
      
      factors << 'current_performance' if subject_data[:current_average]
      factors << 'performance_trend' if subject_data[:trend] != 'insufficient_data'
      factors << 'consistency_pattern' if subject_data[:consistency]
      factors << 'recent_trajectory' if subject_data[:recent_performance]
      
      factors
    end
    
    # Placeholder implementations for complex analysis methods
    def get_time_series_performance(student)
      # Would return detailed time-series performance data
      []
    end
    
    def calculate_learning_velocity(performance_data)
      # Would calculate rate of learning improvement
      0.5
    end
    
    def calculate_learning_acceleration(performance_data)
      # Would calculate acceleration in learning
      0.1
    end
    
    def detect_learning_plateaus(performance_data)
      # Would detect periods of stagnant performance
      false
    end
    
    def predict_breakthrough_potential(performance_data)
      # Would predict likelihood of performance breakthrough
      0.3
    end
    
    def analyze_weekly_patterns(student)
      # Would analyze performance by day of week
      {}
    end
    
    def analyze_assignment_type_performance(student)
      # Would analyze performance by assignment type
      {}
    end
    
    def analyze_submission_timing_patterns(student)
      # Would analyze when student typically submits
      {}
    end
    
    def analyze_difficulty_response_patterns(student)
      # Would analyze how student responds to different difficulty levels
      {}
    end
    
    # Additional helper methods...
    def calculate_recent_trend(grades)
      return 'stable' if grades.count < 3
      
      recent = grades.last(3)
      earlier = grades.first(3)
      
      recent_avg = recent.sum / recent.count.to_f
      earlier_avg = earlier.sum / earlier.count.to_f
      
      difference = recent_avg - earlier_avg
      
      case difference
      when -Float::INFINITY..-5 then 'declining'
      when -5..5 then 'stable'
      else 'improving'
      end
    end
    
    def calculate_overall_trend(submissions)
      return 'insufficient_data' if submissions.count < 5
      
      grades = submissions.pluck(:grade)
      first_quarter = grades.first(grades.count / 4)
      last_quarter = grades.last(grades.count / 4)
      
      return 'stable' if first_quarter.empty? || last_quarter.empty?
      
      first_avg = first_quarter.sum / first_quarter.count.to_f
      last_avg = last_quarter.sum / last_quarter.count.to_f
      
      difference = last_avg - first_avg
      
      case difference
      when -Float::INFINITY..-10 then 'significant_decline'
      when -10..-5 then 'declining'
      when -5..5 then 'stable'
      when 5..10 then 'improving'
      else 'significant_improvement'
      end
    end
    
    def detect_seasonal_patterns(submissions)
      # Would detect patterns based on academic calendar
      # For now, return empty hash
      {}
    end
    
    def calculate_improvement_rate(submissions)
      return 0 if submissions.count < 6
      
      grades = submissions.pluck(:grade)
      
      # Calculate improvement over time using linear regression
      n = grades.count
      x_values = (1..n).to_a
      y_values = grades
      
      x_mean = x_values.sum / n.to_f
      y_mean = y_values.sum / n.to_f
      
      numerator = x_values.zip(y_values).sum { |x, y| (x - x_mean) * (y - y_mean) }
      denominator = x_values.sum { |x| (x - x_mean) ** 2 }
      
      return 0 if denominator.zero?
      
      numerator / denominator.to_f
    end
    
    def calculate_subject_trend(submissions)
      return 'insufficient_data' if submissions.count < 3
      
      grades = submissions.pluck(:grade)
      
      # Simple trend calculation
      first_half = grades.first(grades.count / 2)
      second_half = grades.last(grades.count / 2)
      
      return 'stable' if first_half.empty? || second_half.empty?
      
      first_avg = first_half.sum / first_half.count.to_f
      second_avg = second_half.sum / second_half.count.to_f
      
      difference = second_avg - first_avg
      
      case difference
      when -Float::INFINITY..-7 then 'declining'
      when -7..7 then 'stable'
      else 'improving'
      end
    end
    
    def identify_subject_strengths(submissions)
      # Would identify specific strengths within the subject
      []
    end
    
    def identify_subject_challenges(submissions)
      # Would identify specific challenges within the subject
      []
    end
    
    def generate_subject_recommendations(submissions)
      # Would generate subject-specific recommendations
      []
    end
    
    def analyze_recent_subject_performance(submissions)
      recent_submissions = submissions.last(5)
      return nil if recent_submissions.empty?
      
      recent_grades = recent_submissions.map(&:grade)
      {
        average: recent_grades.sum / recent_grades.count.to_f,
        trend: calculate_recent_trend(recent_grades)
      }
    end
    
    def calculate_analysis_confidence(performance_data)
      confidence_factors = []
      
      confidence_factors << 0.4 if performance_data[:total_submissions] && performance_data[:total_submissions] >= 5
      confidence_factors << 0.3 if performance_data[:grades] && performance_data[:grades].count >= 3
      confidence_factors << 0.2 if performance_data[:subject_breakdown] && performance_data[:subject_breakdown].any?
      confidence_factors << 0.1 if performance_data[:assignment_types] && performance_data[:assignment_types].any?
      
      confidence_factors.sum
    end
    
    def compile_performance_evidence(performance_data)
      evidence = []
      
      if performance_data[:current_average]
        evidence << "Overall average: #{performance_data[:current_average].round(1)}%"
      end
      
      if performance_data[:grades_over_time] && performance_data[:grades_over_time].count >= 3
        trend = calculate_trend_direction(performance_data[:grades_over_time])
        evidence << "Performance trend: #{trend.humanize}"
      end
      
      performance_data[:subject_breakdown]&.each do |subject, data|
        if data[:average] < 65
          evidence << "#{subject}: #{data[:average].round(1)}% (below target)"
        elsif data[:average] > 90
          evidence << "#{subject}: #{data[:average].round(1)}% (excellent)"
        end
      end
      
      evidence
    end
    
    def generate_performance_recommendations(performance_data)
      recommendations = []
      
      if performance_data[:current_average] && performance_data[:current_average] < 70
        recommendations << 'Consider additional academic support'
        recommendations << 'Review study strategies and time management'
      end
      
      trend = calculate_trend_direction(performance_data[:grades_over_time]) if performance_data[:grades_over_time]
      if trend == 'declining'
        recommendations << 'Address declining performance trend immediately'
        recommendations << 'Schedule meeting with academic advisor'
      end
      
      performance_data[:subject_breakdown]&.each do |subject, data|
        if data[:average] < 65
          recommendations << "Focus additional study time on #{subject}"
        end
      end
      
      recommendations
    end
    
    def identify_subject_issues(student, subject)
      # Would analyze specific issues within a subject
      ['concept_understanding', 'time_management', 'assignment_complexity']
    end
    
    def generate_peer_insights(student_metrics, peer_metrics)
      insights = []
      
      peer_averages = calculate_peer_averages(peer_metrics)
      
      student_metrics.each do |metric, value|
        next unless value && peer_averages[metric]
        
        percentile = calculate_percentile(value, peer_metrics.map { |m| m[metric] })
        
        if percentile >= 75
          insights << "Above average in #{metric.to_s.humanize.downcase} (#{percentile}th percentile)"
        elsif percentile <= 25
          insights << "Below average in #{metric.to_s.humanize.downcase} (#{percentile}th percentile)"
        end
      end
      
      insights
    end
  end
end