class GradingRubric < ApplicationRecord
  belongs_to :assignment, optional: true
  belongs_to :department, optional: true
  belongs_to :created_by, class_name: 'User'
  
  has_many :ai_grading_results, dependent: :destroy
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :criteria, presence: true
  validates :total_points, presence: true, numericality: { greater_than: 0 }
  validates :rubric_type, presence: true, inclusion: { in: %w[holistic analytic checklist custom] }
  
  # Scopes
  scope :ai_enabled, -> { where(ai_grading_enabled: true) }
  scope :by_type, ->(type) { where(rubric_type: type) }
  
  # Callbacks
  before_validation :calculate_total_points
  before_save :validate_criteria_structure
  
  # Rubric criteria structure:
  # {
  #   "criteria": [
  #     {
  #       "id": "content_quality",
  #       "name": "Content Quality",
  #       "description": "Accuracy and relevance of content",
  #       "points": 25,
  #       "levels": [
  #         { "name": "Excellent", "points": 25, "description": "..." },
  #         { "name": "Good", "points": 20, "description": "..." },
  #         { "name": "Fair", "points": 15, "description": "..." },
  #         { "name": "Poor", "points": 10, "description": "..." }
  #       ]
  #     }
  #   ]
  # }
  
  def criteria_list
    criteria['criteria'] || []
  end
  
  def criterion_by_id(criterion_id)
    criteria_list.find { |c| c['id'] == criterion_id }
  end
  
  def available_points_for_criterion(criterion_id)
    criterion = criterion_by_id(criterion_id)
    criterion&.dig('points') || 0
  end
  
  def ai_grading_enabled?
    is_ai_enabled && has_ai_compatible_criteria?
  end
  
  def has_ai_compatible_criteria?
    # Check if criteria are structured in a way that AI can process
    return false unless criteria_list.any?
    
    criteria_list.all? do |criterion|
      criterion.key?('ai_prompt') || 
      criterion.key?('ai_keywords') ||
      %w[content_quality grammar_mechanics organization critical_thinking].include?(criterion['id'])
    end
  end
  
  def generate_ai_prompt
    return nil unless ai_grading_enabled?
    
    base_prompt = "Grade this submission based on the following rubric:\n\n"
    
    criteria_list.each do |criterion|
      base_prompt += "#{criterion['name']} (#{criterion['points']} points):\n"
      base_prompt += "#{criterion['description']}\n"
      
      if criterion['ai_prompt']
        base_prompt += "AI Instructions: #{criterion['ai_prompt']}\n"
      end
      
      if criterion['levels']
        base_prompt += "Performance Levels:\n"
        criterion['levels'].each do |level|
          base_prompt += "- #{level['name']} (#{level['points']} pts): #{level['description']}\n"
        end
      end
      
      base_prompt += "\n"
    end
    
    base_prompt += "Please provide:\n"
    base_prompt += "1. A score for each criterion\n"
    base_prompt += "2. Specific feedback for each criterion\n"
    base_prompt += "3. Overall constructive feedback\n"
    base_prompt += "4. Suggestions for improvement\n"
    base_prompt += "5. A confidence score (0-1) for your assessment\n\n"
    
    base_prompt
  end
  
  def duplicate_for_assignment(new_assignment, user)
    new_rubric = self.dup
    new_rubric.assignment = new_assignment
    new_rubric.created_by = user
    new_rubric.title = "#{title} (Copy)"
    new_rubric
  end
  
  # Template methods for common rubric types
  def self.create_holistic_template(assignment, user)
    criteria = {
      'criteria' => [
        {
          'id' => 'overall_quality',
          'name' => 'Overall Quality',
          'description' => 'Overall assessment of the submission',
          'points' => 100,
          'levels' => [
            { 'name' => 'Excellent', 'points' => 90, 'description' => 'Exceeds expectations in all areas' },
            { 'name' => 'Proficient', 'points' => 80, 'description' => 'Meets expectations with good quality' },
            { 'name' => 'Developing', 'points' => 70, 'description' => 'Approaching expectations with some gaps' },
            { 'name' => 'Beginning', 'points' => 60, 'description' => 'Below expectations, needs significant improvement' }
          ]
        }
      ]
    }
    
    create(
      assignment: assignment,
      created_by: user,
      title: 'Holistic Rubric',
      description: 'A holistic rubric for overall assessment',
      criteria: criteria,
      total_points: 100,
      rubric_type: 'holistic',
      is_ai_enabled: true
    )
  end
  
  def self.create_analytic_template(assignment, user)
    criteria = {
      'criteria' => [
        {
          'id' => 'content_quality',
          'name' => 'Content Quality',
          'description' => 'Accuracy, relevance, and depth of content',
          'points' => 25,
          'ai_keywords' => ['accuracy', 'relevance', 'depth', 'understanding'],
          'levels' => [
            { 'name' => 'Excellent', 'points' => 25, 'description' => 'Highly accurate and comprehensive' },
            { 'name' => 'Good', 'points' => 20, 'description' => 'Mostly accurate with good detail' },
            { 'name' => 'Fair', 'points' => 15, 'description' => 'Some accuracy issues or lack of depth' },
            { 'name' => 'Poor', 'points' => 10, 'description' => 'Significant accuracy problems' }
          ]
        },
        {
          'id' => 'organization',
          'name' => 'Organization',
          'description' => 'Logical structure and flow of ideas',
          'points' => 25,
          'ai_keywords' => ['structure', 'flow', 'transitions', 'coherence'],
          'levels' => [
            { 'name' => 'Excellent', 'points' => 25, 'description' => 'Clear, logical organization' },
            { 'name' => 'Good', 'points' => 20, 'description' => 'Generally well organized' },
            { 'name' => 'Fair', 'points' => 15, 'description' => 'Some organizational issues' },
            { 'name' => 'Poor', 'points' => 10, 'description' => 'Poorly organized or confusing' }
          ]
        },
        {
          'id' => 'grammar_mechanics',
          'name' => 'Grammar & Mechanics',
          'description' => 'Proper grammar, spelling, and writing mechanics',
          'points' => 25,
          'ai_keywords' => ['grammar', 'spelling', 'punctuation', 'sentence structure'],
          'levels' => [
            { 'name' => 'Excellent', 'points' => 25, 'description' => 'Error-free or minimal errors' },
            { 'name' => 'Good', 'points' => 20, 'description' => 'Few minor errors' },
            { 'name' => 'Fair', 'points' => 15, 'description' => 'Several errors that may distract' },
            { 'name' => 'Poor', 'points' => 10, 'description' => 'Many errors that impede understanding' }
          ]
        },
        {
          'id' => 'critical_thinking',
          'name' => 'Critical Thinking',
          'description' => 'Analysis, synthesis, and evaluation of ideas',
          'points' => 25,
          'ai_keywords' => ['analysis', 'synthesis', 'evaluation', 'reasoning'],
          'levels' => [
            { 'name' => 'Excellent', 'points' => 25, 'description' => 'Sophisticated analysis and reasoning' },
            { 'name' => 'Good', 'points' => 20, 'description' => 'Good analytical thinking' },
            { 'name' => 'Fair', 'points' => 15, 'description' => 'Limited analysis or reasoning' },
            { 'name' => 'Poor', 'points' => 10, 'description' => 'Little to no critical thinking evident' }
          ]
        }
      ]
    }
    
    create(
      assignment: assignment,
      created_by: user,
      title: 'Analytic Rubric',
      description: 'A detailed analytic rubric for comprehensive assessment',
      criteria: criteria,
      total_points: 100,
      rubric_type: 'analytic',
      is_ai_enabled: true
    )
  end
  
  # Statistics and analytics
  def average_ai_score
    ai_grading_results.where.not(ai_score: nil).average(:ai_score)&.to_f || 0
  end
  
  def ai_accuracy_rate
    reviewed_results = ai_grading_results.where.not(reviewed_by: nil, final_score: nil)
    return 0 if reviewed_results.empty?
    
    accurate_count = reviewed_results.count do |result|
      difference = (result.ai_score - result.final_score).abs
      difference <= (total_points * 0.1) # Within 10% is considered accurate
    end
    
    (accurate_count.to_f / reviewed_results.count * 100).round(1)
  end
  
  def usage_statistics
    {
      total_submissions_graded: ai_grading_results.count,
      average_ai_score: average_ai_score.round(2),
      average_confidence: ai_grading_results.average(:confidence_score)&.to_f&.round(3) || 0,
      ai_accuracy_rate: ai_accuracy_rate,
      pending_reviews: ai_grading_results.where(reviewed_by: nil).count
    }
  end
  
  private
  
  def calculate_total_points
    return unless criteria.present? && criteria['criteria'].is_a?(Array)
    
    self.total_points = criteria['criteria'].sum { |c| c['points'].to_i }
  end
  
  def validate_criteria_structure
    return unless criteria.present?
    
    unless criteria.is_a?(Hash) && criteria['criteria'].is_a?(Array)
      errors.add(:criteria, 'must have a valid structure with criteria array')
      throw(:abort)
    end
    
    criteria['criteria'].each_with_index do |criterion, index|
      unless criterion.is_a?(Hash) && criterion['id'] && criterion['name'] && criterion['points']
        errors.add(:criteria, "criterion at index #{index} is missing required fields")
        throw(:abort)
      end
    end
  end
end