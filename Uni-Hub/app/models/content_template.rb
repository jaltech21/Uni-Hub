class ContentTemplate < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  belongs_to :department, optional: true
  belongs_to :parent_template, class_name: 'ContentTemplate', optional: true
  
  has_many :child_templates, class_name: 'ContentTemplate', 
           foreign_key: 'parent_template_id', dependent: :destroy
  has_many :template_usages, dependent: :destroy
  has_many :template_reviews, dependent: :destroy
  has_many :template_favorites, dependent: :destroy
  has_many :favorited_by, through: :template_favorites, source: :user
  
  # Polymorphic associations for content created from templates
  has_many :assignments, as: :template_source
  has_many :notes, as: :template_source
  has_many :quizzes, as: :template_source
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :template_type, presence: true, inclusion: { in: %w[assignment note quiz generic] }
  validates :content, presence: true
  validates :visibility, presence: true, inclusion: { in: %w[public private department institutional] }
  validates :status, presence: true, inclusion: { in: %w[draft published archived deprecated] }
  validates :version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/, message: 'must be in semantic version format (e.g., 1.0.0)' }
  
  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :public_templates, -> { where(visibility: 'public') }
  scope :department_templates, ->(dept) { where(visibility: 'department', department: dept) }
  scope :institutional_templates, -> { where(visibility: 'institutional') }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :featured, -> { where(is_featured: true) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_category, ->(category) { where(category: category) }
  scope :with_tags, ->(tags) { where("tags ILIKE ANY (ARRAY[?])", tags.map { |tag| "%#{tag}%" }) }
  
  # Callbacks
  before_validation :set_defaults
  before_save :process_tags
  after_create :create_initial_version
  
  # Virtual attributes
  attr_accessor :tag_list
  
  def tag_list
    tags&.split(',')&.map(&:strip) || []
  end
  
  def tag_list=(value)
    if value.is_a?(Array)
      self.tags = value.join(', ')
    elsif value.is_a?(String)
      self.tags = value
    end
  end
  
  # Template access control
  def accessible_to?(user)
    case visibility
    when 'public'
      true
    when 'private'
      created_by == user
    when 'department'
      department && (created_by == user || user.department == department)
    when 'institutional'
      true # All authenticated users can access institutional templates
    else
      false
    end
  end
  
  def editable_by?(user)
    created_by == user || 
    (department && user.admin? && user.department == department)
  end
  
  # Template operations
  def duplicate(user, new_name = nil)
    new_template = self.dup
    new_template.name = new_name || "Copy of #{name}"
    new_template.created_by = user
    new_template.parent_template = self
    new_template.usage_count = 0
    new_template.is_featured = false
    new_template.status = 'draft'
    new_template.version = '1.0.0'
    new_template.visibility = 'private'
    
    if new_template.save
      # Copy metadata
      new_template.metadata = metadata.deep_dup if metadata.present?
      new_template.save
      
      new_template
    else
      nil
    end
  end
  
  def create_content(user, content_attributes = {})
    case template_type
    when 'assignment'
      create_assignment(user, content_attributes)
    when 'note'
      create_note(user, content_attributes)
    when 'quiz'
      create_quiz(user, content_attributes)
    else
      nil
    end
  end
  
  def increment_usage!
    increment!(:usage_count)
    TemplateUsage.create!(
      content_template: self,
      user: nil, # Will be set by caller
      used_at: Time.current
    )
  end
  
  # Version management
  def semantic_version
    @semantic_version ||= Gem::Version.new(version)
  end
  
  def bump_version!(type = :patch)
    current = semantic_version.segments
    
    case type
    when :major
      new_version = "#{current[0] + 1}.0.0"
    when :minor
      new_version = "#{current[0]}.#{current[1] + 1}.0"
    when :patch
      new_version = "#{current[0]}.#{current[1]}.#{current[2] + 1}"
    end
    
    update!(version: new_version)
  end
  
  # Search and filtering
  def self.search(query)
    return all if query.blank?
    
    where(
      "name ILIKE ? OR description ILIKE ? OR tags ILIKE ? OR category ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end
  
  def self.filter_by_criteria(criteria = {})
    templates = published
    
    templates = templates.by_type(criteria[:type]) if criteria[:type].present?
    templates = templates.by_category(criteria[:category]) if criteria[:category].present?
    templates = templates.with_tags(criteria[:tags]) if criteria[:tags].present?
    templates = templates.where(department: criteria[:department]) if criteria[:department].present?
    templates = templates.featured if criteria[:featured] == true
    
    case criteria[:sort]
    when 'popular'
      templates = templates.popular
    when 'recent'
      templates = templates.recent
    when 'name'
      templates = templates.order(:name)
    else
      templates = templates.recent
    end
    
    templates
  end
  
  # Template statistics
  def average_rating
    reviews = template_reviews.where.not(rating: nil)
    return 0 if reviews.empty?
    
    reviews.average(:rating).to_f.round(1)
  end
  
  def total_reviews
    template_reviews.count
  end
  
  def favorited_by?(user)
    template_favorites.exists?(user: user)
  end
  
  def total_favorites
    template_favorites.count
  end
  
  # Content analysis
  def estimated_completion_time
    # Simple heuristic based on content length and type
    base_time = case template_type
                when 'assignment'
                  30 # minutes
                when 'quiz'
                  20
                when 'note'
                  15
                else
                  20
                end
    
    # Adjust based on content length
    content_factor = [content.length / 1000, 1].max
    (base_time * content_factor).to_i
  end
  
  def complexity_score
    # Calculate complexity based on various factors
    score = 0
    
    # Content length factor
    score += [content.length / 500, 10].min
    
    # Metadata complexity
    if metadata.present?
      score += metadata.keys.count
      score += metadata.dig('requirements')&.count || 0
      score += metadata.dig('learning_objectives')&.count || 0
    end
    
    # Template type factor
    score += case template_type
             when 'assignment'
               5
             when 'quiz'
               3
             when 'note'
               2
             else
               1
             end
    
    [score, 1].max
  end
  
  # Template preview
  def preview_data
    {
      id: id,
      name: name,
      description: description,
      type: template_type,
      category: category,
      tags: tag_list,
      created_by: created_by.name,
      department: department&.name,
      usage_count: usage_count,
      rating: average_rating,
      reviews_count: total_reviews,
      favorites_count: total_favorites,
      estimated_time: estimated_completion_time,
      complexity: complexity_score,
      created_at: created_at,
      updated_at: updated_at
    }
  end
  
  private
  
  def set_defaults
    self.usage_count ||= 0
    self.is_featured ||= false
    self.status ||= 'draft'
    self.version ||= '1.0.0'
    self.visibility ||= 'private'
  end
  
  def process_tags
    if tags.present?
      # Normalize tags: lowercase, remove duplicates, limit length
      tag_array = tags.split(',').map(&:strip).map(&:downcase).uniq.first(10)
      self.tags = tag_array.join(', ')
    end
  end
  
  def create_initial_version
    # Create a version record for tracking
    # This would integrate with version control system if needed
  end
  
  def create_assignment(user, attributes)
    assignment_content = parse_assignment_content
    
    Assignment.create(
      title: attributes[:title] || name,
      content: assignment_content[:description],
      due_date: attributes[:due_date],
      user: user,
      template_source: self,
      department: user.department,
      **extract_assignment_metadata
    )
  end
  
  def create_note(user, attributes)
    Note.create(
      title: attributes[:title] || name,
      content: content,
      user: user,
      template_source: self,
      **extract_note_metadata
    )
  end
  
  def create_quiz(user, attributes)
    quiz_data = parse_quiz_content
    
    quiz = Quiz.create(
      title: attributes[:title] || name,
      instructions: quiz_data[:instructions],
      user: user,
      template_source: self,
      department: user.department,
      **extract_quiz_metadata
    )
    
    # Create questions if quiz was created successfully
    if quiz.persisted? && quiz_data[:questions].present?
      quiz_data[:questions].each do |question_data|
        quiz.questions.create(question_data)
      end
    end
    
    quiz
  end
  
  def parse_assignment_content
    # Parse structured assignment content
    {
      description: content,
      requirements: metadata&.dig('requirements') || [],
      learning_objectives: metadata&.dig('learning_objectives') || [],
      rubric: metadata&.dig('rubric')
    }
  end
  
  def parse_quiz_content
    # Parse structured quiz content
    parsed = JSON.parse(content) rescue { instructions: content, questions: [] }
    
    {
      instructions: parsed['instructions'] || content,
      questions: parsed['questions'] || []
    }
  end
  
  def extract_assignment_metadata
    return {} unless metadata.present?
    
    {
      points_possible: metadata['points_possible'],
      submission_types: metadata['submission_types'],
      group_assignment: metadata['group_assignment'] || false
    }.compact
  end
  
  def extract_note_metadata
    return {} unless metadata.present?
    
    {
      category: metadata['category'],
      tags: metadata['tags']&.join(', ')
    }.compact
  end
  
  def extract_quiz_metadata
    return {} unless metadata.present?
    
    {
      time_limit: metadata['time_limit'],
      attempts_allowed: metadata['attempts_allowed'],
      shuffle_questions: metadata['shuffle_questions'] || false
    }.compact
  end
end