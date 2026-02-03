class Room < ApplicationRecord
  belongs_to :campus
  
  # Associations
  has_many :equipment, dependent: :nullify
  has_many :resource_bookings, as: :bookable, dependent: :destroy
  has_many :active_bookings, -> { where(status: ['confirmed', 'in_progress']) }, 
           class_name: 'ResourceBooking', as: :bookable
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 50 },
            uniqueness: { scope: :campus_id, case_sensitive: false }
  validates :building, presence: true, length: { maximum: 100 }
  validates :room_type, presence: true, 
            inclusion: { in: %w[classroom laboratory office conference_room auditorium library_room 
                               study_room computer_lab meeting_room workshop storage] }
  validates :capacity, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }
  validates :status, presence: true,
            inclusion: { in: %w[available occupied maintenance unavailable reserved] }
  validates :access_level, inclusion: { in: %w[public restricted private admin_only] }
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :advance_booking_days, numericality: { greater_than: 0, less_than_or_equal_to: 365 }
  validates :max_booking_duration_hours, numericality: { greater_than: 0, less_than_or_equal_to: 168 }
  
  # Scopes
  scope :available, -> { where(status: 'available') }
  scope :by_type, ->(type) { where(room_type: type) }
  scope :by_building, ->(building) { where(building: building) }
  scope :by_capacity, ->(min_capacity) { where('capacity >= ?', min_capacity) }
  scope :requires_approval, -> { where(requires_approval: true) }
  scope :public_access, -> { where(access_level: 'public') }
  scope :with_equipment, -> { joins(:equipment).distinct }
  
  before_validation :normalize_code
  before_save :update_availability_status
  
  def full_name
    "#{building} #{code} - #{name}"
  end
  
  def location_description
    floor_text = floor ? "Floor #{floor}" : 'Ground Level'
    "#{building}, #{floor_text}"
  end
  
  def available?
    status == 'available'
  end
  
  def occupied?
    status == 'occupied'
  end
  
  def under_maintenance?
    status == 'maintenance'
  end
  
  # Availability checking
  def available_at?(start_time, end_time)
    return false unless available?
    return false unless within_operating_hours?(start_time, end_time)
    !has_conflicting_bookings?(start_time, end_time)
  end
  
  def has_conflicting_bookings?(start_time, end_time)
    resource_bookings.where(status: ['confirmed', 'in_progress'])
                    .where('start_time < ? AND end_time > ?', end_time, start_time)
                    .exists?
  end
  
  def within_operating_hours?(start_time, end_time)
    return true if availability_hours.blank?
    
    day_name = start_time.strftime('%A').downcase
    hours = availability_hours[day_name]
    return false if hours.blank? || hours['closed']
    
    room_open = Time.parse(hours['open']) rescue nil
    room_close = Time.parse(hours['close']) rescue nil
    return true if room_open.nil? || room_close.nil?
    
    booking_start = start_time.strftime('%H:%M')
    booking_end = end_time.strftime('%H:%M')
    
    booking_start >= room_open.strftime('%H:%M') && booking_end <= room_close.strftime('%H:%M')
  end
  
  def next_available_slot(from_time = Time.current, duration_hours = 1)
    search_end = from_time + advance_booking_days.days
    current_time = from_time
    
    while current_time < search_end
      end_time = current_time + duration_hours.hours
      return { start_time: current_time, end_time: end_time } if available_at?(current_time, end_time)
      
      # Move to next hour
      current_time = current_time.beginning_of_hour + 1.hour
    end
    
    nil
  end
  
  # Equipment management
  def available_equipment
    equipment.where(status: 'available')
  end
  
  def equipment_by_type(type)
    equipment.where(equipment_type: type)
  end
  
  def has_equipment?(equipment_type)
    equipment_by_type(equipment_type).any?
  end
  
  # Amenities and features
  def has_amenity?(amenity_name)
    return false if amenities.blank?
    amenities.include?(amenity_name)
  end
  
  def amenities_list
    return [] if amenities.blank?
    amenities.is_a?(Array) ? amenities : []
  end
  
  def add_amenity(amenity_name)
    current_amenities = amenities_list
    current_amenities << amenity_name unless current_amenities.include?(amenity_name)
    update!(amenities: current_amenities)
  end
  
  def remove_amenity(amenity_name)
    current_amenities = amenities_list
    current_amenities.delete(amenity_name)
    update!(amenities: current_amenities)
  end
  
  # Booking rules and restrictions
  def booking_rules_summary
    rules = booking_rules || {}
    {
      advance_notice_hours: rules['advance_notice_hours'] || 1,
      max_duration_hours: max_booking_duration_hours,
      requires_approval: requires_approval?,
      recurring_allowed: rules['recurring_allowed'] != false,
      weekend_booking: rules['weekend_booking'] != false
    }
  end
  
  def can_book_recurring?
    rules = booking_rules || {}
    rules['recurring_allowed'] != false
  end
  
  def minimum_advance_notice
    rules = booking_rules || {}
    (rules['advance_notice_hours'] || 1).hours
  end
  
  # Statistics and reporting
  def utilization_rate(start_date = 1.month.ago, end_date = Time.current)
    total_hours = business_hours_in_range(start_date, end_date)
    return 0 if total_hours.zero?
    
    booked_hours = resource_bookings
                  .where(status: ['confirmed', 'completed'])
                  .where(start_time: start_date..end_date)
                  .sum('EXTRACT(EPOCH FROM (end_time - start_time)) / 3600')
    
    ((booked_hours / total_hours) * 100).round(2)
  end
  
  def booking_frequency(period = 1.month)
    resource_bookings.where(created_at: period.ago..Time.current).count
  end
  
  def peak_usage_hours
    bookings = resource_bookings.where(status: ['confirmed', 'completed'])
                               .where('start_time >= ?', 3.months.ago)
    
    hour_counts = bookings.group('EXTRACT(hour from start_time)').count
    hour_counts.sort_by { |hour, count| -count }.first(3).to_h
  end
  
  def revenue_generated(start_date = 1.month.ago, end_date = Time.current)
    return 0 unless hourly_rate
    
    resource_bookings
      .where(status: ['confirmed', 'completed'])
      .where(start_time: start_date..end_date)
      .sum('total_cost')
  end
  
  # Maintenance and status management
  def mark_for_maintenance(reason = nil)
    update!(
      status: 'maintenance',
      equipment: (equipment || []) << {
        maintenance_started: Time.current.iso8601,
        reason: reason
      }
    )
  end
  
  def complete_maintenance
    update!(status: 'available')
  end
  
  def maintenance_history
    return [] unless equipment.is_a?(Array)
    equipment.select { |item| item.is_a?(Hash) && item['maintenance_started'] }
  end
  
  # Search and filtering
  def self.search(query)
    return all if query.blank?
    
    where(
      'name ILIKE ? OR code ILIKE ? OR building ILIKE ? OR description ILIKE ?',
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end
  
  def self.available_for_booking(start_time, end_time, capacity_needed = 1)
    available.by_capacity(capacity_needed)
             .select { |room| room.available_at?(start_time, end_time) }
  end
  
  def self.by_features(required_amenities = [], required_equipment = [])
    rooms = all
    
    unless required_amenities.empty?
      rooms = rooms.select { |room| (required_amenities - room.amenities_list).empty? }
    end
    
    unless required_equipment.empty?
      rooms = rooms.joins(:equipment)
                   .where(equipment: { equipment_type: required_equipment })
                   .group('rooms.id')
                   .having('COUNT(DISTINCT equipment.equipment_type) = ?', required_equipment.size)
    end
    
    rooms
  end
  
  private
  
  def normalize_code
    self.code = code&.upcase&.strip
  end
  
  def update_availability_status
    # Update status based on current bookings
    if status_was != 'maintenance' && has_active_booking?
      self.status = 'occupied' if status == 'available'
    elsif status == 'occupied' && !has_active_booking?
      self.status = 'available'
    end
  end
  
  def has_active_booking?
    active_bookings.where('start_time <= ? AND end_time > ?', Time.current, Time.current).exists?
  end
  
  def business_hours_in_range(start_date, end_date)
    # Simplified calculation - assumes 8 hours per business day
    business_days = (start_date.to_date..end_date.to_date).count { |date| date.on_weekday? }
    business_days * 8
  end
end
