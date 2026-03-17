class LearningInsight < ApplicationRecord
  belongs_to :user
  belongs_to :department, optional: true
  belongs_to :schedule, optional: true
  
  validates :insight_type, presence: true
  validates :confidence_score, presence: true, inclusion: { in: 0.0..1.0 }
  validates :priority, presence: true, inclusion: { in: %w[low medium high critical] }
  validates :status, presence: true, inclusion: { in: %w[active dismissed implemented archived] }
  
  serialize :data, coder: JSON
  serialize :metadata, coder: JSON
  serialize :recommendations, coder: JSON
  
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(insight_type: type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :recent, -> { where('created_at >= ?', 30.days.ago) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_department, ->(dept) { where(department: dept) }
  scope :high_confidence, -> { where('confidence_score >= ?', 0.7) }
  
  # Insight types
  INSIGHT_TYPES = %w[
    at_risk_prediction
    performance_decline
    engagement_drop
    learning_style_mismatch
    content_difficulty
    time_management_issue
    peer_comparison
    improvement_opportunity
    strength_identification
    behavioral_pattern
  ].freeze
  
  def self.generate_insights_for_user(user, options = {})
    insights = []
    
    # At-risk student prediction
    at_risk_data = PredictiveAnalyticsService.predict_at_risk_students([user])
    if at_risk_data[user.id] && at_risk_data[user.id][:risk_score] > 0.7
      insights << create_at_risk_insight(user, at_risk_data[user.id])
    end
    
    # Performance trend analysis
    performance_data = PerformanceAnalysisService.analyze_trends(user)
    if performance_data[:declining_trend]
      insights << create_performance_decline_insight(user, performance_data)
    end
    
    # Engagement analysis
    engagement_data = EngagementAnalysisService.analyze_engagement(user)
    if engagement_data[:engagement_score] < 0.4
      insights << create_engagement_insight(user, engagement_data)
    end
    
    # Learning style analysis
    learning_style_data = LearningStyleAnalysisService.analyze_learning_style(user)
    if learning_style_data[:mismatch_detected]
      insights << create_learning_style_insight(user, learning_style_data)
    end
    
    # Content difficulty analysis
    content_data = ContentAnalysisService.analyze_difficulty_match(user)
    if content_data[:difficulty_mismatch]
      insights << create_content_difficulty_insight(user, content_data)
    end
    
    insights.compact
  end
  
  def self.generate_class_insights(schedule)
    insights = []
    students = schedule.users.where(role: 'student')
    
    # Class performance analysis
    class_data = ClassAnalyticsService.analyze_class_performance(schedule)
    if class_data[:needs_attention]
      insights << create_class_performance_insight(schedule, class_data)
    end
    
    # Student comparison insights
    comparison_data = StudentComparisonService.analyze_peer_performance(students)
    comparison_data[:outliers].each do |student_id, data|
      student = students.find(student_id)
      insights << create_peer_comparison_insight(student, data)
    end
    
    insights.compact
  end
  
  def self.generate_institutional_insights(department = nil)
    insights = []
    
    # Institutional trend analysis
    trend_data = InstitutionalAnalyticsService.analyze_trends(department)
    if trend_data[:concerning_trends].any?
      insights += create_institutional_insights(trend_data)
    end
    
    insights.compact
  end
  
  def title
    case insight_type
    when 'at_risk_prediction'
      "Student At Risk - #{confidence_percentage}% confidence"
    when 'performance_decline'
      "Performance Decline Detected"
    when 'engagement_drop'
      "Low Engagement Alert"
    when 'learning_style_mismatch'
      "Learning Style Mismatch"
    when 'content_difficulty'
      "Content Difficulty Issue"
    when 'time_management_issue'
      "Time Management Concern"
    when 'peer_comparison'
      "Peer Performance Comparison"
    when 'improvement_opportunity'
      "Improvement Opportunity"
    when 'strength_identification'
      "Strength Identified"
    when 'behavioral_pattern'
      "Behavioral Pattern Detected"
    else
      "Learning Insight"
    end
  end
  
  def description
    data['description'] || generate_description
  end
  
  def confidence_percentage
    (confidence_score * 100).round(1)
  end
  
  def is_critical?
    priority == 'critical'
  end
  
  def is_high_priority?
    priority.in?(['high', 'critical'])
  end
  
  def dismiss!
    update!(status: 'dismissed', dismissed_at: Time.current)
  end
  
  def implement!
    update!(status: 'implemented', implemented_at: Time.current)
  end
  
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
  
  def recommendation_actions
    return [] unless recommendations.present?
    
    recommendations['actions'] || []
  end
  
  def predicted_outcome
    data['predicted_outcome'] if data.present?
  end
  
  def supporting_evidence
    data['evidence'] || []
  end
  
  def related_metrics
    metadata['metrics'] || {}
  end
  
  def expires_at
    metadata['expires_at']&.to_datetime
  end
  
  def expired?
    expires_at && Time.current > expires_at
  end
  
  private
  
  def self.create_at_risk_insight(user, risk_data)
    create!(
      user: user,
      department: user.department,
      insight_type: 'at_risk_prediction',
      confidence_score: risk_data[:risk_score],
      priority: determine_priority(risk_data[:risk_score]),
      status: 'active',
      data: {
        description: generate_at_risk_description(risk_data),
        risk_factors: risk_data[:risk_factors],
        predicted_outcome: risk_data[:predicted_outcome],
        evidence: risk_data[:evidence]
      },
      recommendations: {
        actions: generate_at_risk_recommendations(risk_data),
        interventions: risk_data[:suggested_interventions]
      },
      metadata: {
        generated_at: Time.current,
        expires_at: 30.days.from_now,
        model_version: '1.0',
        metrics: risk_data[:metrics]
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create at-risk insight: #{e.message}"
    nil
  end
  
  def self.create_performance_decline_insight(user, performance_data)
    create!(
      user: user,
      department: user.department,
      insight_type: 'performance_decline',
      confidence_score: performance_data[:confidence],
      priority: 'high',
      status: 'active',
      data: {
        description: "Performance has declined by #{performance_data[:decline_percentage]}% over the past #{performance_data[:time_period]}",
        trend_direction: 'declining',
        decline_rate: performance_data[:decline_rate],
        contributing_factors: performance_data[:factors],
        evidence: performance_data[:evidence]
      },
      recommendations: {
        actions: [
          'Schedule one-on-one meeting with instructor',
          'Review recent assignments for patterns',
          'Consider additional study resources',
          'Assess workload and time management'
        ]
      },
      metadata: {
        generated_at: Time.current,
        expires_at: 14.days.from_now,
        metrics: performance_data[:metrics]
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create performance decline insight: #{e.message}"
    nil
  end
  
  def self.create_engagement_insight(user, engagement_data)
    create!(
      user: user,
      department: user.department,
      insight_type: 'engagement_drop',
      confidence_score: engagement_data[:confidence],
      priority: 'medium',
      status: 'active',
      data: {
        description: "Student engagement has dropped to #{(engagement_data[:engagement_score] * 100).round(1)}%",
        engagement_score: engagement_data[:engagement_score],
        engagement_factors: engagement_data[:factors],
        recent_activities: engagement_data[:activities],
        evidence: engagement_data[:evidence]
      },
      recommendations: {
        actions: generate_engagement_recommendations(engagement_data)
      },
      metadata: {
        generated_at: Time.current,
        expires_at: 21.days.from_now,
        metrics: engagement_data[:metrics]
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create engagement insight: #{e.message}"
    nil
  end
  
  def self.create_learning_style_insight(user, style_data)
    create!(
      user: user,
      department: user.department,
      insight_type: 'learning_style_mismatch',
      confidence_score: style_data[:confidence],
      priority: 'medium',
      status: 'active',
      data: {
        description: "Learning style mismatch detected between student preferences and content delivery",
        preferred_style: style_data[:preferred_style],
        current_delivery: style_data[:current_delivery],
        mismatch_areas: style_data[:mismatch_areas],
        evidence: style_data[:evidence]
      },
      recommendations: {
        actions: generate_learning_style_recommendations(style_data)
      },
      metadata: {
        generated_at: Time.current,
        expires_at: 45.days.from_now,
        metrics: style_data[:metrics]
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create learning style insight: #{e.message}"
    nil
  end
  
  def self.create_content_difficulty_insight(user, content_data)
    priority = content_data[:difficulty_level] == 'too_hard' ? 'high' : 'medium'
    
    create!(
      user: user,
      department: user.department,
      insight_type: 'content_difficulty',
      confidence_score: content_data[:confidence],
      priority: priority,
      status: 'active',
      data: {
        description: generate_content_difficulty_description(content_data),
        difficulty_level: content_data[:difficulty_level],
        affected_subjects: content_data[:subjects],
        skill_gaps: content_data[:skill_gaps],
        evidence: content_data[:evidence]
      },
      recommendations: {
        actions: generate_content_difficulty_recommendations(content_data)
      },
      metadata: {
        generated_at: Time.current,
        expires_at: 30.days.from_now,
        metrics: content_data[:metrics]
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create content difficulty insight: #{e.message}"
    nil
  end
  
  def self.determine_priority(confidence_score)
    case confidence_score
    when 0.9..1.0
      'critical'
    when 0.7..0.89
      'high'
    when 0.5..0.69
      'medium'
    else
      'low'
    end
  end
  
  def self.generate_at_risk_description(risk_data)
    factors = risk_data[:risk_factors].join(', ')
    "Student shows high risk of academic difficulty based on: #{factors}. " \
    "Immediate intervention recommended to prevent potential failure."
  end
  
  def self.generate_at_risk_recommendations(risk_data)
    base_recommendations = [
      'Schedule immediate intervention meeting',
      'Review academic support resources',
      'Assess current workload and commitments',
      'Consider tutoring or peer support'
    ]
    
    # Add specific recommendations based on risk factors
    risk_specific = []
    risk_data[:risk_factors].each do |factor|
      case factor
      when 'low_attendance'
        risk_specific << 'Address attendance issues'
      when 'declining_grades'
        risk_specific << 'Review recent assignments and feedback'
      when 'low_engagement'
        risk_specific << 'Explore engagement strategies'
      when 'missed_deadlines'
        risk_specific << 'Implement time management support'
      end
    end
    
    base_recommendations + risk_specific
  end
  
  def self.generate_engagement_recommendations(engagement_data)
    recommendations = []
    
    engagement_data[:factors].each do |factor|
      case factor
      when 'low_participation'
        recommendations << 'Encourage class participation'
        recommendations << 'Consider alternative participation methods'
      when 'infrequent_logins'
        recommendations << 'Send engagement reminders'
        recommendations << 'Check technical barriers'
      when 'minimal_note_taking'
        recommendations << 'Provide note-taking strategies'
        recommendations << 'Share template or guide'
      when 'low_quiz_attempts'
        recommendations << 'Review quiz accessibility'
        recommendations << 'Provide practice opportunities'
      end
    end
    
    recommendations.presence || ['General engagement strategies needed']
  end
  
  def self.generate_learning_style_recommendations(style_data)
    style = style_data[:preferred_style]
    
    case style
    when 'visual'
      [
        'Provide more visual learning materials',
        'Use diagrams and infographics',
        'Encourage mind mapping techniques'
      ]
    when 'auditory'
      [
        'Include more audio content',
        'Encourage discussion participation',
        'Suggest recording lectures for review'
      ]
    when 'kinesthetic'
      [
        'Incorporate hands-on activities',
        'Suggest interactive simulations',
        'Encourage practical applications'
      ]
    when 'reading_writing'
      [
        'Provide extensive reading materials',
        'Encourage written reflections',
        'Suggest note-taking strategies'
      ]
    else
      ['Adapt content delivery to student preferences']
    end
  end
  
  def self.generate_content_difficulty_description(content_data)
    level = content_data[:difficulty_level]
    case level
    when 'too_hard'
      "Content appears too challenging for student's current skill level. Student may benefit from prerequisite review."
    when 'too_easy'
      "Content may be below student's capability level. Consider providing more challenging materials."
    else
      "Content difficulty mismatch detected."
    end
  end
  
  def self.generate_content_difficulty_recommendations(content_data)
    level = content_data[:difficulty_level]
    
    case level
    when 'too_hard'
      [
        'Review prerequisite concepts',
        'Provide additional foundational resources',
        'Consider personalized study plan',
        'Arrange peer tutoring or study group'
      ]
    when 'too_easy'
      [
        'Provide advanced or enrichment materials',
        'Consider accelerated pathway',
        'Offer independent study opportunities',
        'Suggest peer mentoring role'
      ]
    else
      ['Adjust content difficulty to match student level']
    end
  end
  
  def generate_description
    case insight_type
    when 'at_risk_prediction'
      "Machine learning analysis indicates this student has a #{confidence_percentage}% probability of academic difficulty."
    when 'performance_decline'
      "Student's academic performance has shown a declining trend over recent assignments."
    when 'engagement_drop'
      "Student engagement metrics have dropped below optimal levels."
    when 'learning_style_mismatch'
      "There appears to be a mismatch between student's learning preferences and current content delivery."
    when 'content_difficulty'
      "Content difficulty level may not be appropriately matched to student's current abilities."
    else
      "AI-generated insight about student's learning patterns."
    end
  end
end