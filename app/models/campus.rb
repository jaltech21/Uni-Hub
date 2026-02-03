class Campus < ApplicationRecord
  belongs_to :university
  has_many :departments, dependent: :nullify
  has_many :campus_programs, dependent: :destroy
  has_many :initiated_collaborations, class_name: 'CrossCampusCollaboration', 
           foreign_key: 'initiating_campus_id', dependent: :destroy
  
  # Users associated with this campus
  has_many :users, through: :departments
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 10 }, 
            uniqueness: { scope: :university_id, case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :country, inclusion: { in: ISO3166::Country.all.map(&:alpha2) }
  validates :latitude, :longitude, numericality: true, allow_blank: true
  validates :student_capacity, :faculty_count, :staff_count, 
            numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :main_campus, -> { where(is_main_campus: true) }
  scope :by_country, ->(country) { where(country: country) }
  scope :by_state, ->(state) { where(state: state) }
  scope :established_after, ->(date) { where('established_date >= ?', date) }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  
  # Callbacks
  before_validation :normalize_code
  before_save :ensure_single_main_campus
  after_create :create_default_settings
  
  def full_address
    [address, city, state, postal_code, country_name].compact.join(', ')
  end
  
  def country_name
    country.present? ? ISO3166::Country[country]&.name : nil
  end
  
  def coordinates
    return nil unless latitude && longitude
    [latitude, longitude]
  end
  
  def distance_to(other_campus)
    return nil unless coordinates && other_campus.coordinates
    
    # Haversine formula for distance calculation
    rad_per_deg = Math::PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # in meters
    
    dlat_rad = (other_campus.latitude - latitude) * rad_per_deg
    dlon_rad = (other_campus.longitude - longitude) * rad_per_deg
    
    lat1_rad = latitude * rad_per_deg
    lat2_rad = other_campus.latitude * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rm * c # Distance in meters
  end
  
  def total_enrollment
    campus_programs.sum(:current_enrollment)
  end
  
  def program_count_by_level
    campus_programs.active.group(:degree_level).count
  end
  
  def utilization_rate
    return 0 if student_capacity.nil? || student_capacity.zero?
    (total_enrollment.to_f / student_capacity * 100).round(2)
  end
  
  # Campus statistics
  def statistics
    {
      total_programs: campus_programs.active.count,
      total_enrollment: total_enrollment,
      utilization_rate: utilization_rate,
      faculty_count: faculty_count || 0,
      staff_count: staff_count || 0,
      departments_count: departments.active.count,
      active_collaborations: initiated_collaborations.where(status: 'active').count
    }
  end
  
  # Operating hours management
  def operating_hours_for_day(day)
    return nil unless operating_hours.is_a?(Hash)
    operating_hours[day.to_s.downcase]
  end
  
  def open_now?
    return true unless operating_hours.present?
    
    current_time = Time.current.in_time_zone(timezone)
    day = current_time.strftime('%A').downcase
    hours = operating_hours_for_day(day)
    
    return false unless hours && hours['open'] && hours['close']
    
    open_time = Time.parse("#{hours['open']} #{timezone}")
    close_time = Time.parse("#{hours['close']} #{timezone}")
    
    current_time.between?(open_time, close_time)
  end
  
  # Contact persons management
  def primary_contact
    return nil unless contact_persons.is_a?(Array) && contact_persons.any?
    contact_persons.find { |contact| contact['primary'] == true } || contact_persons.first
  end
  
  def contacts_by_type(type)
    return [] unless contact_persons.is_a?(Array)
    contact_persons.select { |contact| contact['type'] == type }
  end
  
  # Collaboration methods
  def participating_collaborations
    CrossCampusCollaboration.where("participating_campuses @> ?", [id].to_json)
  end
  
  def all_collaborations
    CrossCampusCollaboration.where(
      "initiating_campus_id = ? OR participating_campuses @> ?", 
      id, [id].to_json
    )
  end
  
  def collaboration_statistics
    collaborations = all_collaborations
    {
      total: collaborations.count,
      active: collaborations.where(status: 'active').count,
      completed: collaborations.where(status: 'completed').count,
      as_initiator: initiated_collaborations.count,
      as_participant: participating_collaborations.count
    }
  end
  
  # Resource sharing capabilities
  def shared_resources
    return [] unless all_collaborations.any?
    
    all_collaborations.where(status: 'active')
                     .pluck(:resources_shared)
                     .compact
                     .flat_map { |resources| resources.is_a?(Array) ? resources : [] }
                     .uniq
  end
  
  # Performance metrics
  def performance_metrics
    programs = campus_programs.active
    
    {
      average_program_enrollment: programs.average(:current_enrollment)&.round(2) || 0,
      enrollment_growth_rate: calculate_enrollment_growth_rate,
      program_completion_rate: calculate_program_completion_rate,
      faculty_to_student_ratio: calculate_faculty_student_ratio,
      accredited_programs_percentage: calculate_accredited_programs_percentage
    }
  end
  
  private
  
  def normalize_code
    self.code = code&.upcase&.strip
  end
  
  def ensure_single_main_campus
    if is_main_campus? && is_main_campus_changed?
      # Ensure only one main campus per university
      university.campuses.where.not(id: id).update_all(is_main_campus: false)
    end
  end
  
  def create_default_settings
    # Create default operating hours
    default_hours = {
      'monday' => { 'open' => '08:00', 'close' => '18:00' },
      'tuesday' => { 'open' => '08:00', 'close' => '18:00' },
      'wednesday' => { 'open' => '08:00', 'close' => '18:00' },
      'thursday' => { 'open' => '08:00', 'close' => '18:00' },
      'friday' => { 'open' => '08:00', 'close' => '18:00' },
      'saturday' => { 'open' => '09:00', 'close' => '15:00' },
      'sunday' => { 'closed' => true }
    }
    
    update_column(:operating_hours, default_hours) if operating_hours.blank?
  end
  
  def calculate_enrollment_growth_rate
    # This would need historical data - placeholder implementation
    0
  end
  
  def calculate_program_completion_rate
    # This would need student completion data - placeholder implementation
    85.0
  end
  
  def calculate_faculty_student_ratio
    return 0 if faculty_count.nil? || faculty_count.zero?
    (total_enrollment.to_f / faculty_count).round(2)
  end
  
  def calculate_accredited_programs_percentage
    total_programs = campus_programs.active.count
    return 0 if total_programs.zero?
    
    accredited_programs = campus_programs.active.where.not(accreditation_body: [nil, '']).count
    (accredited_programs.to_f / total_programs * 100).round(2)
  end
end