class EngagementAnalysisService
  include ActiveModel::Model
  
  class << self
    def analyze_engagement(student, time_range = 30.days.ago..Time.current)
      engagement_metrics = calculate_engagement_metrics(student, time_range)
      behavioral_patterns = analyze_behavioral_patterns(student, time_range)
      
      {
        engagement_score: calculate_overall_engagement_score(engagement_metrics),
        engagement_level: determine_engagement_level(engagement_metrics),
        factors: identify_engagement_factors(engagement_metrics, behavioral_patterns),
        activities: get_recent_activities(student, time_range),
        trends: analyze_engagement_trends(student, time_range),
        confidence: calculate_engagement_confidence(engagement_metrics),
        evidence: compile_engagement_evidence(engagement_metrics),
        recommendations: generate_engagement_recommendations(engagement_metrics, behavioral_patterns)
      }
    end
    
    def predict_engagement_decline(student)
      historical_engagement = get_engagement_history(student, 90.days.ago..Time.current)
      current_patterns = analyze_current_engagement_patterns(student)
      
      decline_probability = calculate_decline_probability(historical_engagement, current_patterns)
      
      {
        decline_probability: decline_probability,
        risk_level: determine_decline_risk_level(decline_probability),
        warning_signs: identify_decline_warning_signs(current_patterns),
        intervention_recommendations: suggest_engagement_interventions(decline_probability, current_patterns)
      }
    end
    
    def analyze_participation_patterns(student)
      participation_data = get_participation_data(student)
      
      {
        class_participation: analyze_class_participation(participation_data),
        discussion_engagement: analyze_discussion_engagement(participation_data),
        assignment_interaction: analyze_assignment_interaction(participation_data),
        peer_interaction: analyze_peer_interaction(participation_data)
      }
    end
    
    def identify_engagement_triggers(student)
      activity_data = get_detailed_activity_data(student)
      
      {
        positive_triggers: identify_positive_triggers(activity_data),
        negative_triggers: identify_negative_triggers(activity_data),
        optimal_conditions: identify_optimal_conditions(activity_data),
        disengagement_patterns: identify_disengagement_patterns(activity_data)
      }
    end
    
    def compare_engagement_with_peers(student)
      return {} unless student.department
      
      peers = User.where(role: 'student', department: student.department)
                  .where.not(id: student.id)
      
      student_engagement = calculate_engagement_metrics(student)
      peer_engagements = peers.map { |peer| calculate_engagement_metrics(peer) }.compact
      
      {
        student_percentile: calculate_engagement_percentile(student_engagement, peer_engagements),
        comparison_insights: generate_engagement_comparison_insights(student_engagement, peer_engagements),
        relative_strengths: identify_relative_engagement_strengths(student_engagement, peer_engagements),
        areas_for_improvement: identify_relative_engagement_gaps(student_engagement, peer_engagements)
      }
    end
    
    private
    
    def calculate_engagement_metrics(student, time_range = 30.days.ago..Time.current)
      # Platform activity metrics
      notes_activity = calculate_notes_activity(student, time_range)
      attendance_engagement = calculate_attendance_engagement(student, time_range)
      assignment_engagement = calculate_assignment_engagement(student, time_range)
      collaboration_engagement = calculate_collaboration_engagement(student, time_range)
      
      {
        notes_activity: notes_activity,
        attendance_engagement: attendance_engagement,
        assignment_engagement: assignment_engagement,
        collaboration_engagement: collaboration_engagement,
        overall_activity_frequency: calculate_activity_frequency(student, time_range),
        consistency_score: calculate_engagement_consistency(student, time_range),
        depth_of_interaction: calculate_interaction_depth(student, time_range)
      }
    end
    
    def calculate_notes_activity(student, time_range)
      notes = student.notes.where(updated_at: time_range)
      
      {
        notes_created: notes.count,
        notes_updated: notes.where.not(created_at: time_range.begin..time_range.end).count,
        average_note_length: calculate_average_note_length(notes),
        note_frequency: notes.count / time_range.to_i.days.to_f,
        engagement_score: calculate_notes_engagement_score(notes, time_range)
      }
    end
    
    def calculate_attendance_engagement(student, time_range)
      attendance_records = student.attendance_records.where(created_at: time_range)
      
      return { engagement_score: 0.5 } if attendance_records.empty?
      
      present_count = attendance_records.where(status: ['present', 'late']).count
      total_count = attendance_records.count
      
      {
        attendance_rate: present_count / total_count.to_f,
        consistency: calculate_attendance_consistency(attendance_records),
        punctuality: calculate_punctuality_score(attendance_records),
        engagement_score: calculate_attendance_engagement_score(attendance_records)
      }
    end
    
    def calculate_assignment_engagement(student, time_range)
      submissions = student.submissions.joins(:assignment)
                          .where(assignments: { created_at: time_range })
      
      return { engagement_score: 0.5 } if submissions.empty?
      
      total_assignments = get_available_assignments_count(student, time_range)
      
      {
        submission_rate: submissions.count / total_assignments.to_f,
        on_time_submissions: calculate_on_time_submission_rate(submissions),
        quality_effort: calculate_submission_quality_effort(submissions),
        improvement_trajectory: analyze_submission_improvement(submissions),
        engagement_score: calculate_assignment_engagement_score(submissions, total_assignments)
      }
    end
    
    def calculate_collaboration_engagement(student, time_range)
      # This would analyze collaborative activities like shared notes, group work, etc.
      shared_notes = student.notes.where(updated_at: time_range, is_shared: true)
      
      {
        shared_content_count: shared_notes.count,
        collaboration_frequency: shared_notes.count / time_range.to_i.days.to_f,
        engagement_score: calculate_collaboration_engagement_score(shared_notes, time_range)
      }
    end
    
    def calculate_activity_frequency(student, time_range)
      # Calculate overall platform activity frequency
      activities = []
      
      # Add note activities
      student.notes.where(updated_at: time_range).find_each do |note|
        activities << note.updated_at
      end
      
      # Add submission activities
      student.submissions.where(created_at: time_range).find_each do |submission|
        activities << submission.created_at
      end
      
      # Add attendance activities
      student.attendance_records.where(created_at: time_range).find_each do |record|
        activities << record.created_at
      end
      
      return 0 if activities.empty?
      
      # Calculate daily activity frequency
      unique_days = activities.map(&:to_date).uniq.count
      unique_days / time_range.to_i.days.to_f
    end
    
    def calculate_engagement_consistency(student, time_range)
      # Analyze consistency of engagement over time
      daily_activities = {}
      
      time_range.to_i.days.times do |days_ago|
        date = days_ago.days.ago.to_date
        daily_activities[date] = 0
        
        # Count activities for this day
        daily_activities[date] += student.notes.where(updated_at: date.beginning_of_day..date.end_of_day).count
        daily_activities[date] += student.submissions.where(created_at: date.beginning_of_day..date.end_of_day).count
        daily_activities[date] += student.attendance_records.where(created_at: date.beginning_of_day..date.end_of_day).count
      end
      
      activities = daily_activities.values
      return 0.5 if activities.empty?
      
      # Calculate consistency (lower variance = higher consistency)
      mean = activities.sum / activities.count.to_f
      variance = activities.map { |a| (a - mean) ** 2 }.sum / activities.count.to_f
      
      # Normalize consistency score
      [1.0 - (Math.sqrt(variance) / 5.0), 0.0].max
    end
    
    def calculate_interaction_depth(student, time_range)
      # Analyze depth of interactions with content
      depth_score = 0.0
      total_interactions = 0
      
      # Note depth (longer notes = deeper interaction)
      student.notes.where(updated_at: time_range).find_each do |note|
        content_length = note.content&.length || 0
        depth_score += [content_length / 1000.0, 1.0].min
        total_interactions += 1
      end
      
      # Assignment depth (effort indicators)
      student.submissions.joins(:assignment)
            .where(assignments: { created_at: time_range })
            .find_each do |submission|
        # Analyze submission timing (earlier submission might indicate more effort)
        if submission.submitted_at && submission.assignment.due_date
          days_early = (submission.assignment.due_date - submission.submitted_at) / 1.day
          depth_score += [days_early / 7.0, 1.0].min if days_early > 0
        else
          depth_score += 0.5 # Default for submissions without timing data
        end
        total_interactions += 1
      end
      
      return 0.5 if total_interactions.zero?
      
      depth_score / total_interactions
    end
    
    def calculate_overall_engagement_score(engagement_metrics)
      scores = []
      weights = {}
      
      # Weight different engagement aspects
      if engagement_metrics[:notes_activity]
        scores << engagement_metrics[:notes_activity][:engagement_score]
        weights[:notes] = 0.25
      end
      
      if engagement_metrics[:attendance_engagement]
        scores << engagement_metrics[:attendance_engagement][:engagement_score]
        weights[:attendance] = 0.30
      end
      
      if engagement_metrics[:assignment_engagement]
        scores << engagement_metrics[:assignment_engagement][:engagement_score]
        weights[:assignments] = 0.35
      end
      
      if engagement_metrics[:collaboration_engagement]
        scores << engagement_metrics[:collaboration_engagement][:engagement_score]
        weights[:collaboration] = 0.10
      end
      
      return 0.5 if scores.empty?
      
      # Calculate weighted average
      total_weight = weights.values.sum
      weighted_sum = scores.each_with_index.sum { |score, index| score * weights.values[index] }
      
      weighted_sum / total_weight
    end
    
    def determine_engagement_level(engagement_metrics)
      overall_score = calculate_overall_engagement_score(engagement_metrics)
      
      case overall_score
      when 0.8..1.0 then 'highly_engaged'
      when 0.6..0.79 then 'engaged'
      when 0.4..0.59 then 'moderately_engaged'
      when 0.2..0.39 then 'low_engagement'
      else 'disengaged'
      end
    end
    
    def identify_engagement_factors(engagement_metrics, behavioral_patterns)
      factors = []
      
      # Analyze each engagement component
      if engagement_metrics[:notes_activity] && engagement_metrics[:notes_activity][:engagement_score] < 0.4
        factors << 'low_content_creation'
      end
      
      if engagement_metrics[:attendance_engagement] && engagement_metrics[:attendance_engagement][:engagement_score] < 0.6
        factors << 'poor_attendance'
      end
      
      if engagement_metrics[:assignment_engagement] && engagement_metrics[:assignment_engagement][:engagement_score] < 0.5
        factors << 'low_assignment_engagement'
      end
      
      if engagement_metrics[:overall_activity_frequency] && engagement_metrics[:overall_activity_frequency] < 0.3
        factors << 'infrequent_platform_use'
      end
      
      if engagement_metrics[:consistency_score] && engagement_metrics[:consistency_score] < 0.4
        factors << 'inconsistent_participation'
      end
      
      factors
    end
    
    def get_recent_activities(student, time_range)
      activities = []
      
      # Recent notes
      student.notes.where(updated_at: time_range)
            .order(updated_at: :desc)
            .limit(5)
            .each do |note|
        activities << {
          type: 'note',
          title: note.title,
          date: note.updated_at,
          engagement_indicator: calculate_note_engagement_indicator(note)
        }
      end
      
      # Recent submissions
      student.submissions.joins(:assignment)
            .where(created_at: time_range)
            .order(created_at: :desc)
            .limit(5)
            .each do |submission|
        activities << {
          type: 'submission',
          title: submission.assignment.title,
          date: submission.created_at,
          engagement_indicator: calculate_submission_engagement_indicator(submission)
        }
      end
      
      # Recent attendance
      student.attendance_records.where(created_at: time_range)
            .order(created_at: :desc)
            .limit(5)
            .each do |record|
        activities << {
          type: 'attendance',
          title: "Class attendance",
          date: record.created_at,
          status: record.status,
          engagement_indicator: record.status == 'present' ? 'positive' : 'neutral'
        }
      end
      
      activities.sort_by { |a| a[:date] }.reverse.first(10)
    end
    
    def analyze_engagement_trends(student, time_range)
      # Analyze engagement trends over time
      weekly_engagement = calculate_weekly_engagement_scores(student, time_range)
      
      return { trend: 'insufficient_data' } if weekly_engagement.count < 3
      
      trend_direction = calculate_engagement_trend_direction(weekly_engagement)
      
      {
        trend: trend_direction,
        weekly_scores: weekly_engagement,
        volatility: calculate_engagement_volatility(weekly_engagement),
        recent_change: calculate_recent_engagement_change(weekly_engagement)
      }
    end
    
    def analyze_behavioral_patterns(student, time_range)
      {
        activity_times: analyze_activity_timing_patterns(student, time_range),
        session_patterns: analyze_session_patterns(student, time_range),
        content_preferences: analyze_content_preferences(student, time_range),
        interaction_styles: analyze_interaction_styles(student, time_range)
      }
    end
    
    # Helper methods for detailed calculations
    def calculate_average_note_length(notes)
      return 0 if notes.empty?
      
      lengths = notes.map { |note| note.content&.length || 0 }
      lengths.sum / lengths.count.to_f
    end
    
    def calculate_notes_engagement_score(notes, time_range)
      return 0.5 if notes.empty?
      
      # Factor in frequency, length, and updates
      frequency_score = [notes.count / time_range.to_i.days.to_f, 1.0].min
      length_score = [calculate_average_note_length(notes) / 500.0, 1.0].min
      update_score = notes.where.not(created_at: time_range.begin..time_range.end).count / notes.count.to_f
      
      (frequency_score * 0.4) + (length_score * 0.4) + (update_score * 0.2)
    end
    
    def calculate_attendance_consistency(attendance_records)
      return 0.5 if attendance_records.count < 5
      
      # Analyze patterns in attendance status
      status_changes = attendance_records.order(:created_at)
                                        .each_cons(2)
                                        .count { |a, b| a.status != b.status }
      
      # Lower changes = higher consistency
      [1.0 - (status_changes / attendance_records.count.to_f), 0.0].max
    end
    
    def calculate_punctuality_score(attendance_records)
      return 0.5 if attendance_records.empty?
      
      present_on_time = attendance_records.where(status: 'present').count
      total_present = attendance_records.where(status: ['present', 'late']).count
      
      return 0.5 if total_present.zero?
      
      present_on_time / total_present.to_f
    end
    
    def calculate_attendance_engagement_score(attendance_records)
      return 0.5 if attendance_records.empty?
      
      attendance_rate = attendance_records.where(status: ['present', 'late']).count / attendance_records.count.to_f
      punctuality = calculate_punctuality_score(attendance_records)
      consistency = calculate_attendance_consistency(attendance_records)
      
      (attendance_rate * 0.5) + (punctuality * 0.3) + (consistency * 0.2)
    end
    
    def get_available_assignments_count(student, time_range)
      # Get assignments available to the student in the time range
      student_schedules = student.schedules
      return 1 if student_schedules.empty? # Avoid division by zero
      
      Assignment.joins(:schedule)
                .where(schedule: student_schedules)
                .where(created_at: time_range)
                .count
    end
    
    def calculate_on_time_submission_rate(submissions)
      return 0.5 if submissions.empty?
      
      on_time_count = submissions.joins(:assignment)
                                .where('submissions.submitted_at <= assignments.due_date')
                                .count
      
      on_time_count / submissions.count.to_f
    end
    
    def calculate_submission_quality_effort(submissions)
      # This would analyze submission quality indicators
      # For now, return a moderate score
      0.7
    end
    
    def analyze_submission_improvement(submissions)
      return 'stable' if submissions.count < 3
      
      graded_submissions = submissions.where.not(grade: nil).order(:created_at)
      return 'stable' if graded_submissions.count < 3
      
      grades = graded_submissions.pluck(:grade)
      first_half = grades.first(grades.count / 2)
      second_half = grades.last(grades.count / 2)
      
      return 'stable' if first_half.empty? || second_half.empty?
      
      first_avg = first_half.sum / first_half.count.to_f
      second_avg = second_half.sum / second_half.count.to_f
      
      case second_avg - first_avg
      when -Float::INFINITY..-5 then 'declining'
      when -5..5 then 'stable'
      else 'improving'
      end
    end
    
    def calculate_assignment_engagement_score(submissions, total_assignments)
      return 0.5 if total_assignments.zero?
      
      submission_rate = submissions.count / total_assignments.to_f
      on_time_rate = calculate_on_time_submission_rate(submissions)
      quality_score = calculate_submission_quality_effort(submissions)
      
      (submission_rate * 0.4) + (on_time_rate * 0.3) + (quality_score * 0.3)
    end
    
    def calculate_collaboration_engagement_score(shared_notes, time_range)
      return 0.1 if shared_notes.empty?
      
      frequency = shared_notes.count / time_range.to_i.days.to_f
      [frequency, 1.0].min
    end
    
    def calculate_note_engagement_indicator(note)
      content_length = note.content&.length || 0
      
      case content_length
      when 0..100 then 'low'
      when 101..500 then 'medium'
      else 'high'
      end
    end
    
    def calculate_submission_engagement_indicator(submission)
      if submission.submitted_at && submission.assignment.due_date
        days_early = (submission.assignment.due_date - submission.submitted_at) / 1.day
        
        case days_early
        when -Float::INFINITY..-1 then 'low' # Late submission
        when -1..1 then 'medium' # Last minute
        else 'high' # Early submission
        end
      else
        'medium'
      end
    end
    
    def calculate_weekly_engagement_scores(student, time_range)
      weekly_scores = {}
      
      # Calculate engagement score for each week
      (time_range.begin.to_date..time_range.end.to_date).step(7) do |week_start|
        week_end = [week_start + 6.days, time_range.end.to_date].min
        week_range = week_start.beginning_of_day..week_end.end_of_day
        
        week_metrics = calculate_engagement_metrics(student, week_range)
        weekly_scores[week_start] = calculate_overall_engagement_score(week_metrics)
      end
      
      weekly_scores
    end
    
    def calculate_engagement_trend_direction(weekly_scores)
      return 'insufficient_data' if weekly_scores.count < 3
      
      scores = weekly_scores.values
      first_half = scores.first(scores.count / 2)
      second_half = scores.last(scores.count / 2)
      
      return 'stable' if first_half.empty? || second_half.empty?
      
      first_avg = first_half.sum / first_half.count.to_f
      second_avg = second_half.sum / second_half.count.to_f
      
      difference = second_avg - first_avg
      
      case difference
      when -1.0..-0.1 then 'declining'
      when -0.1..0.1 then 'stable'
      else 'improving'
      end
    end
    
    def calculate_engagement_volatility(weekly_scores)
      scores = weekly_scores.values
      return 0.5 if scores.count < 2
      
      mean = scores.sum / scores.count.to_f
      variance = scores.map { |s| (s - mean) ** 2 }.sum / scores.count.to_f
      
      Math.sqrt(variance)
    end
    
    def calculate_recent_engagement_change(weekly_scores)
      scores = weekly_scores.values
      return 0 if scores.count < 2
      
      scores.last - scores[-2]
    end
    
    # Placeholder implementations for complex behavioral analysis
    def analyze_activity_timing_patterns(student, time_range)
      # Would analyze when student is most active
      { peak_hours: [14, 15, 16], peak_days: ['Monday', 'Wednesday'] }
    end
    
    def analyze_session_patterns(student, time_range)
      # Would analyze session length and frequency
      { average_session_length: 45, sessions_per_week: 5 }
    end
    
    def analyze_content_preferences(student, time_range)
      # Would analyze what types of content student engages with most
      { preferred_content_types: ['notes', 'assignments'], least_engaged: ['quizzes'] }
    end
    
    def analyze_interaction_styles(student, time_range)
      # Would analyze how student interacts with platform
      { interaction_style: 'focused', collaboration_preference: 'individual' }
    end
    
    def calculate_engagement_confidence(engagement_metrics)
      confidence_factors = []
      
      confidence_factors << 0.25 if engagement_metrics[:notes_activity]
      confidence_factors << 0.25 if engagement_metrics[:attendance_engagement]
      confidence_factors << 0.25 if engagement_metrics[:assignment_engagement]
      confidence_factors << 0.15 if engagement_metrics[:overall_activity_frequency]
      confidence_factors << 0.1 if engagement_metrics[:consistency_score]
      
      confidence_factors.sum
    end
    
    def compile_engagement_evidence(engagement_metrics)
      evidence = []
      
      overall_score = calculate_overall_engagement_score(engagement_metrics)
      evidence << "Overall engagement score: #{(overall_score * 100).round(1)}%"
      
      if engagement_metrics[:overall_activity_frequency]
        frequency = engagement_metrics[:overall_activity_frequency]
        evidence << "Platform activity frequency: #{(frequency * 100).round(1)}% of days"
      end
      
      if engagement_metrics[:notes_activity] && engagement_metrics[:notes_activity][:notes_created]
        count = engagement_metrics[:notes_activity][:notes_created]
        evidence << "Notes created: #{count}"
      end
      
      if engagement_metrics[:assignment_engagement] && engagement_metrics[:assignment_engagement][:submission_rate]
        rate = engagement_metrics[:assignment_engagement][:submission_rate]
        evidence << "Assignment submission rate: #{(rate * 100).round(1)}%"
      end
      
      evidence
    end
    
    def generate_engagement_recommendations(engagement_metrics, behavioral_patterns)
      recommendations = []
      
      overall_score = calculate_overall_engagement_score(engagement_metrics)
      
      if overall_score < 0.4
        recommendations << 'Immediate engagement intervention needed'
        recommendations << 'Schedule one-on-one meeting to discuss barriers'
      end
      
      if engagement_metrics[:notes_activity] && engagement_metrics[:notes_activity][:engagement_score] < 0.3
        recommendations << 'Encourage more active note-taking'
        recommendations << 'Provide note-taking templates and strategies'
      end
      
      if engagement_metrics[:attendance_engagement] && engagement_metrics[:attendance_engagement][:engagement_score] < 0.5
        recommendations << 'Address attendance issues'
        recommendations << 'Explore flexible participation options'
      end
      
      if engagement_metrics[:assignment_engagement] && engagement_metrics[:assignment_engagement][:engagement_score] < 0.4
        recommendations << 'Increase assignment engagement'
        recommendations << 'Consider assignment format alternatives'
      end
      
      recommendations
    end
    
    # Additional helper methods for advanced analysis
    def get_engagement_history(student, time_range)
      # Would return detailed engagement history
      []
    end
    
    def analyze_current_engagement_patterns(student)
      # Would analyze current patterns for prediction
      {}
    end
    
    def calculate_decline_probability(historical_engagement, current_patterns)
      # Would calculate probability of engagement decline
      0.3
    end
    
    def determine_decline_risk_level(probability)
      case probability
      when 0.7..1.0 then 'high'
      when 0.4..0.69 then 'medium'
      else 'low'
      end
    end
    
    def identify_decline_warning_signs(patterns)
      # Would identify specific warning signs
      ['decreased_activity', 'irregular_patterns']
    end
    
    def suggest_engagement_interventions(probability, patterns)
      # Would suggest specific interventions
      ['personalized_outreach', 'engagement_strategies']
    end
    
    def get_participation_data(student)
      # Would get detailed participation data
      {}
    end
    
    def analyze_class_participation(participation_data)
      # Would analyze class participation patterns
      {}
    end
    
    def analyze_discussion_engagement(participation_data)
      # Would analyze discussion forum engagement
      {}
    end
    
    def analyze_assignment_interaction(participation_data)
      # Would analyze assignment interaction patterns
      {}
    end
    
    def analyze_peer_interaction(participation_data)
      # Would analyze peer interaction patterns
      {}
    end
    
    def get_detailed_activity_data(student)
      # Would get detailed activity data for trigger analysis
      {}
    end
    
    def identify_positive_triggers(activity_data)
      # Would identify what triggers positive engagement
      []
    end
    
    def identify_negative_triggers(activity_data)
      # Would identify what triggers disengagement
      []
    end
    
    def identify_optimal_conditions(activity_data)
      # Would identify optimal conditions for engagement
      {}
    end
    
    def identify_disengagement_patterns(activity_data)
      # Would identify disengagement patterns
      {}
    end
    
    def calculate_engagement_percentile(student_engagement, peer_engagements)
      return 50 if peer_engagements.empty?
      
      student_score = calculate_overall_engagement_score(student_engagement)
      peer_scores = peer_engagements.map { |pe| calculate_overall_engagement_score(pe) }.compact
      
      return 50 if peer_scores.empty?
      
      below_count = peer_scores.count { |score| score < student_score }
      (below_count / peer_scores.count.to_f * 100).round
    end
    
    def generate_engagement_comparison_insights(student_engagement, peer_engagements)
      # Would generate insights from peer comparison
      []
    end
    
    def identify_relative_engagement_strengths(student_engagement, peer_engagements)
      # Would identify relative strengths
      []
    end
    
    def identify_relative_engagement_gaps(student_engagement, peer_engagements)
      # Would identify areas where student lags behind peers
      []
    end
  end
end