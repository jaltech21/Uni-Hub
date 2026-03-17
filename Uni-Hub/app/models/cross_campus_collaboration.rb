class CrossCampusCollaboration < ApplicationRecord
  # Associations
  belongs_to :lead_campus, class_name: 'Campus'
  belongs_to :partner_campus, class_name: 'Campus'
  belongs_to :project_lead, class_name: 'User', optional: true
  belongs_to :department, optional: true
  
  has_many :collaboration_participants, dependent: :destroy
  has_many :participants, through: :collaboration_participants, source: :user
  has_many :collaboration_milestones, dependent: :destroy
  has_many :collaboration_resources, dependent: :destroy
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :collaboration_type, presence: true,
            inclusion: { in: %w[research academic_program joint_degree 
                              student_exchange faculty_exchange resource_sharing
                              conference event workshop training] }
  validates :status, presence: true,
            inclusion: { in: %w[planning active on_hold completed cancelled] }
  validates :priority_level, presence: true,
            inclusion: { in: %w[low medium high critical] }
  validates :budget, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :spent_amount, 
            numericality: { less_than_or_equal_to: :budget },
            if: -> { budget.present? && spent_amount.present? }
  validates :lead_campus_id, presence: true
  validates :partner_campus_id, presence: true
  validate :different_campuses
  validate :valid_date_range
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(collaboration_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority_level: priority) }
  scope :for_campus, ->(campus_id) { 
    where('lead_campus_id = ? OR partner_campus_id = ?', campus_id, campus_id) 
  }
  scope :research_projects, -> { where(collaboration_type: 'research') }
  scope :academic_programs, -> { where(collaboration_type: ['academic_program', 'joint_degree']) }
  scope :exchanges, -> { where(collaboration_type: ['student_exchange', 'faculty_exchange']) }
  scope :overdue, -> { where('end_date < ? AND status IN (?)', Date.current, ['planning', 'active']) }
  scope :ending_soon, -> { where('end_date BETWEEN ? AND ? AND status = ?', 
                                  Date.current, 30.days.from_now, 'active') }
  scope :over_budget, -> { 
    where('budget IS NOT NULL AND spent_amount IS NOT NULL AND spent_amount > budget') 
  }
  scope :recent, -> { where('created_at >= ?', 30.days.ago) }
  
  # Callbacks
  before_save :update_progress_percentage
  before_save :update_financial_status
  after_create :initialize_collaboration_data
  after_update :notify_status_changes
  
  def campus_names
    "#{lead_campus.name} & #{partner_campus.name}"
  end
  
  def duration_days
    return nil unless start_date && end_date
    (end_date - start_date).to_i
  end
  
  def days_remaining
    return nil unless end_date
    return 0 if end_date < Date.current
    (end_date - Date.current).to_i
  end
  
  def days_elapsed
    return 0 unless start_date
    return duration_days if completed? || cancelled?
    [(Date.current - start_date).to_i, 0].max
  end
  
  def progress_status
    return 'not_started' if start_date > Date.current
    return 'overdue' if end_date < Date.current && !completed?
    return 'completed' if completed?
    return 'on_track' if progress_percentage >= expected_progress_percentage
    'behind_schedule'
  end
  
  def expected_progress_percentage
    return 0 unless start_date && end_date && start_date <= Date.current
    return 100 if Date.current >= end_date
    
    total_duration = (end_date - start_date).to_f
    elapsed = (Date.current - start_date).to_f
    ((elapsed / total_duration) * 100).round(2)
  end
  
  def budget_status
    return 'no_budget' if budget.nil?
    return 'over_budget' if spent_amount && spent_amount > budget
    return 'on_budget' if spent_amount && spent_amount <= budget * 0.9
    return 'approaching_limit' if spent_amount && spent_amount > budget * 0.8
    'under_budget'
  end
  
  def budget_utilization_percentage
    return 0 if budget.nil? || budget.zero? || spent_amount.nil?
    ((spent_amount / budget) * 100).round(2)
  end
  
  def remaining_budget
    return nil if budget.nil?
    return 0 if spent_amount.nil?
    [budget - spent_amount, 0].max
  end
  
  # Status methods
  def active?
    status == 'active'
  end
  
  def completed?
    status == 'completed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def on_hold?
    status == 'on_hold'
  end
  
  # Milestone management
  def add_milestone(title, due_date, description = nil)
    collaboration_milestones.create!(
      title: title,
      due_date: due_date,
      description: description,
      status: 'pending'
    )
  end
  
  def complete_milestone(milestone_id)
    milestone = collaboration_milestones.find(milestone_id)
    milestone.update!(status: 'completed', completed_at: Time.current)
    recalculate_progress!
  end
  
  def overdue_milestones
    collaboration_milestones.where('due_date < ? AND status != ?', Date.current, 'completed')
  end
  
  def upcoming_milestones(days = 7)
    collaboration_milestones.where(
      'due_date BETWEEN ? AND ? AND status = ?', 
      Date.current, 
      days.days.from_now, 
      'pending'
    )
  end
  
  def milestone_completion_rate
    total_milestones = collaboration_milestones.count
    return 0 if total_milestones.zero?
    
    completed_milestones = collaboration_milestones.where(status: 'completed').count
    ((completed_milestones.to_f / total_milestones) * 100).round(2)
  end
  
  # Participant management
  def add_participant(user, role = 'collaborator')
    collaboration_participants.create!(
      user: user,
      role: role,
      joined_at: Time.current
    )
  end
  
  def remove_participant(user)
    participant = collaboration_participants.find_by(user: user)
    participant&.update!(left_at: Time.current, status: 'inactive')
  end
  
  def participant_count
    collaboration_participants.where(status: 'active').count
  end
  
  def leads
    collaboration_participants.where(role: ['lead', 'co_lead']).includes(:user)
  end
  
  def collaborators
    collaboration_participants.where(role: 'collaborator').includes(:user)
  end
  
  def advisors
    collaboration_participants.where(role: 'advisor').includes(:user)
  end
  
  # Resource management
  def add_resource(resource_type, name, description = nil, url = nil)
    collaboration_resources.create!(
      resource_type: resource_type,
      name: name,
      description: description,
      url: url
    )
  end
  
  def resources_by_type(type)
    collaboration_resources.where(resource_type: type)
  end
  
  def shared_documents
    resources_by_type('document')
  end
  
  def shared_datasets
    resources_by_type('dataset')
  end
  
  def shared_equipment
    resources_by_type('equipment')
  end
  
  # Financial management
  def add_expense(amount, description, expense_category = 'general')
    current_spent = spent_amount || 0
    update!(
      spent_amount: current_spent + amount,
      financial_notes: append_financial_note(description, amount, expense_category)
    )
  end
  
  def expense_breakdown
    return {} unless financial_notes.is_a?(Array)
    
    expenses = financial_notes.select { |note| note['type'] == 'expense' }
    expenses.group_by { |expense| expense['category'] }
            .transform_values { |items| items.sum { |item| item['amount'] } }
  end
  
  def monthly_spending
    return {} unless financial_notes.is_a?(Array)
    
    expenses = financial_notes.select { |note| note['type'] == 'expense' }
    expenses.group_by { |expense| Date.parse(expense['date']).beginning_of_month }
            .transform_values { |items| items.sum { |item| item['amount'] } }
  end
  
  # Reporting and analytics
  def collaboration_summary
    {
      basic_info: {
        title: title,
        type: collaboration_type,
        status: status,
        priority: priority_level,
        duration_days: duration_days,
        progress: "#{progress_percentage}%"
      },
      timeline: {
        start_date: start_date,
        end_date: end_date,
        days_elapsed: days_elapsed,
        days_remaining: days_remaining,
        progress_status: progress_status
      },
      financial: {
        budget: budget,
        spent: spent_amount,
        remaining: remaining_budget,
        utilization: "#{budget_utilization_percentage}%",
        status: budget_status
      },
      participation: {
        total_participants: participant_count,
        leads_count: leads.count,
        collaborators_count: collaborators.count,
        advisors_count: advisors.count
      },
      milestones: {
        total: collaboration_milestones.count,
        completed: collaboration_milestones.where(status: 'completed').count,
        overdue: overdue_milestones.count,
        completion_rate: "#{milestone_completion_rate}%"
      }
    }
  end
  
  def performance_metrics
    {
      timeline_performance: calculate_timeline_performance,
      budget_performance: calculate_budget_performance,
      milestone_performance: milestone_completion_rate,
      participation_score: calculate_participation_score,
      overall_health: calculate_overall_health
    }
  end
  
  # Campus collaboration analytics
  def self.collaboration_statistics(campus_id = nil)
    scope = campus_id ? for_campus(campus_id) : all
    
    {
      total_collaborations: scope.count,
      active_collaborations: scope.active.count,
      completed_collaborations: scope.where(status: 'completed').count,
      by_type: scope.group(:collaboration_type).count,
      by_priority: scope.group(:priority_level).count,
      total_budget: scope.sum(:budget),
      total_spent: scope.sum(:spent_amount),
      average_duration: scope.where.not(start_date: nil, end_date: nil)
                           .average('end_date - start_date')&.to_i
    }
  end
  
  def self.campus_collaboration_network(campus_id)
    collaborations = for_campus(campus_id)
    
    partners = collaborations.map do |collab|
      partner_id = collab.lead_campus_id == campus_id ? 
                   collab.partner_campus_id : collab.lead_campus_id
      {
        campus_id: partner_id,
        campus_name: Campus.find(partner_id).name,
        collaboration_count: collaborations.where(
          '(lead_campus_id = ? AND partner_campus_id = ?) OR (lead_campus_id = ? AND partner_campus_id = ?)',
          campus_id, partner_id, partner_id, campus_id
        ).count,
        active_collaborations: collaborations.active.where(
          '(lead_campus_id = ? AND partner_campus_id = ?) OR (lead_campus_id = ? AND partner_campus_id = ?)',
          campus_id, partner_id, partner_id, campus_id
        ).count
      }
    end
    
    partners.group_by { |p| p[:campus_id] }
            .transform_values(&:first)
            .values
  end
  
  private
  
  def different_campuses
    errors.add(:partner_campus_id, "cannot be the same as lead campus") if lead_campus_id == partner_campus_id
  end
  
  def valid_date_range
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end
  
  def update_progress_percentage
    if collaboration_milestones.any?
      self.progress_percentage = milestone_completion_rate
    elsif start_date && end_date && start_date <= Date.current
      self.progress_percentage = expected_progress_percentage
    else
      self.progress_percentage = 0
    end
  end
  
  def update_financial_status
    if budget && spent_amount
      self.budget_status = calculate_budget_status
    end
  end
  
  def initialize_collaboration_data
    # Set default financial notes structure
    if financial_notes.blank?
      self.update_column(:financial_notes, [])
    end
    
    # Create initial milestone if none exist
    if collaboration_milestones.empty?
      add_milestone("Project Kickoff", start_date || 1.week.from_now)
    end
  end
  
  def notify_status_changes
    # Placeholder for notification logic
    if status_changed? && status_was.present?
      puts "Collaboration '#{title}' status changed from #{status_was} to #{status}"
    end
  end
  
  def recalculate_progress!
    update!(progress_percentage: milestone_completion_rate)
  end
  
  def append_financial_note(description, amount, category)
    notes = financial_notes || []
    notes << {
      type: 'expense',
      description: description,
      amount: amount,
      category: category,
      date: Date.current.iso8601,
      timestamp: Time.current.iso8601
    }
    notes
  end
  
  def calculate_timeline_performance
    return 50 unless start_date && end_date && start_date <= Date.current
    
    expected = expected_progress_percentage
    actual = progress_percentage
    
    return 100 if actual >= expected
    return 0 if expected.zero?
    
    ((actual / expected) * 100).round(2)
  end
  
  def calculate_budget_performance
    return 100 if budget.nil? || spent_amount.nil?
    return 0 if budget.zero?
    
    utilization = budget_utilization_percentage
    return 100 if utilization <= 90
    return 50 if utilization <= 100
    0 # Over budget
  end
  
  def calculate_participation_score
    base_score = [participant_count * 10, 100].min
    
    # Bonus for having defined roles
    role_bonus = (leads.count + advisors.count) * 5
    
    # Penalty for inactive participants
    inactive_penalty = collaboration_participants.where(status: 'inactive').count * 5
    
    [base_score + role_bonus - inactive_penalty, 0].max
  end
  
  def calculate_overall_health
    timeline_score = calculate_timeline_performance
    budget_score = calculate_budget_performance
    milestone_score = milestone_completion_rate
    participation_score = calculate_participation_score
    
    weights = {
      timeline: 0.3,
      budget: 0.25,
      milestones: 0.3,
      participation: 0.15
    }
    
    overall = (timeline_score * weights[:timeline]) +
              (budget_score * weights[:budget]) +
              (milestone_score * weights[:milestones]) +
              (participation_score * weights[:participation])
    
    overall.round(2)
  end
  
  def calculate_budget_status
    return 'no_budget' if budget.nil?
    return 'over_budget' if spent_amount && spent_amount > budget
    return 'on_budget' if spent_amount && spent_amount <= budget * 0.9
    return 'approaching_limit' if spent_amount && spent_amount > budget * 0.8
    'under_budget'
  end
end