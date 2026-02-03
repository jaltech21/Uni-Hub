class Equipment < ApplicationRecord
  belongs_to :campus
  belongs_to :room, optional: true
  
  # Associations
  has_many :resource_bookings, as: :bookable, dependent: :destroy
  has_many :active_bookings, -> { where(status: ['confirmed', 'in_progress']) }, 
           class_name: 'ResourceBooking', as: :bookable
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 50 },
            uniqueness: { scope: :campus_id, case_sensitive: false }
  validates :equipment_type, presence: true, length: { maximum: 100 }
  validates :status, presence: true,
            inclusion: { in: %w[available in_use maintenance retired damaged reserved] }
  validates :condition_rating, inclusion: { in: %w[excellent good fair poor] }, allow_blank: true
  validates :purchase_cost, :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :max_booking_duration_hours, numericality: { greater_than: 0, less_than_or_equal_to: 168 }
  
  # Scopes
  scope :available, -> { where(status: 'available') }
  scope :portable, -> { where(portable: true) }
  scope :stationary, -> { where(portable: false) }
  scope :by_type, ->(type) { where(equipment_type: type) }
  scope :by_room, ->(room_id) { where(room_id: room_id) }
  scope :requires_training, -> { where(requires_training: true) }
  scope :under_warranty, -> { where('warranty_expiry > ?', Date.current) }
  scope :warranty_expiring, -> { where('warranty_expiry BETWEEN ? AND ?', Date.current, 30.days.from_now) }
  
  before_validation :normalize_code
  before_save :update_availability_status
  after_create :initialize_maintenance_schedule
  
  def full_name
    "#{brand} #{model} - #{name}".strip.gsub(/\s+/, ' ')
  end
  
  def display_name
    model.present? ? "#{name} (#{model})" : name
  end
  
  def available?
    status == 'available'
  end
  
  def operational?
    %w[available in_use reserved].include?(status)
  end
  
  def available_at?(start_time, end_time)
    return false unless operational?
    !has_conflicting_bookings?(start_time, end_time)
  end
  
  def has_conflicting_bookings?(start_time, end_time)
    resource_bookings.where(status: ['confirmed', 'in_progress'])
                    .where('start_time < ? AND end_time > ?', end_time, start_time)
                    .exists?
  end
  
  def maintenance_due?
    return false unless maintenance_schedule.is_a?(Hash)
    
    last_maintenance = maintenance_schedule['last_maintenance_date']
    return true if last_maintenance.nil?
    
    interval_days = maintenance_schedule['interval_days'] || 90
    last_date = Date.parse(last_maintenance) rescue nil
    return false unless last_date
    
    Date.current >= last_date + interval_days.days
  end
  
  def days_until_maintenance
    return nil unless maintenance_schedule.is_a?(Hash)
    
    last_maintenance = maintenance_schedule['last_maintenance_date']
    return 0 if last_maintenance.nil?
    
    interval_days = maintenance_schedule['interval_days'] || 90
    last_date = Date.parse(last_maintenance) rescue Date.current
    next_maintenance = last_date + interval_days.days
    
    (next_maintenance - Date.current).to_i
  end
  
  def under_warranty?
    warranty_expiry.present? && warranty_expiry > Date.current
  end
  
  def warranty_status
    return 'no_warranty' if warranty_expiry.nil?
    return 'expired' if warranty_expiry <= Date.current
    return 'expiring_soon' if warranty_expiry <= 30.days.from_now
    'active'
  end
  
  def utilization_rate(start_date = 1.month.ago, end_date = Time.current)
    total_hours = ((end_date - start_date) / 1.hour).to_f
    return 0 if total_hours.zero?
    
    booked_hours = resource_bookings
                  .where(status: ['confirmed', 'completed'])
                  .where(start_time: start_date..end_date)
                  .sum('EXTRACT(EPOCH FROM (end_time - start_time)) / 3600')
    
    ((booked_hours / total_hours) * 100).round(2)
  end
  
  def current_location
    if portable && room
      "#{room.building} - #{room.code} (Portable)"
    elsif room
      "#{room.building} - #{room.code}"
    else
      "Campus Storage"
    end
  end
  
  def self.search(query)
    return all if query.blank?
    
    where('name ILIKE ? OR code ILIKE ? OR equipment_type ILIKE ? OR brand ILIKE ? OR model ILIKE ?',
          "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%")
  end
  
  def self.available_for_booking(start_time, end_time)
    available.select { |equipment| equipment.available_at?(start_time, end_time) }
  end
  
  private
  
  def normalize_code
    self.code = code&.upcase&.strip
  end
  
  def update_availability_status
    if status_was != 'maintenance' && status_was != 'damaged' && has_active_booking?
      self.status = 'in_use' if status == 'available'
    elsif status == 'in_use' && !has_active_booking?
      self.status = 'available'
    end
  end
  
  def has_active_booking?
    active_bookings.where('start_time <= ? AND end_time > ?', Time.current, Time.current).exists?
  end
  
  def initialize_maintenance_schedule
    return if maintenance_schedule.present?
    
    default_schedule = {
      interval_days: 90,
      last_maintenance_date: Date.current.iso8601,
      maintenance_type: 'routine'
    }
    
    update_column(:maintenance_schedule, default_schedule)
  end
end
