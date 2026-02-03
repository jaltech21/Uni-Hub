class ResourceBooking < ApplicationRecord
  belongs_to :user
  belongs_to :bookable, polymorphic: true
  belongs_to :approved_by, class_name: 'User', optional: true
  
  # Associations
  has_many :conflicts_as_primary, class_name: 'ResourceConflict', 
           foreign_key: :primary_booking_id, dependent: :destroy
  has_many :conflicts_as_conflicting, class_name: 'ResourceConflict', 
           foreign_key: :conflicting_booking_id, dependent: :destroy
  
  validates :booking_type, presence: true, 
            inclusion: { in: %w[room equipment facility one_time recurring event meeting class] }
  validates :start_time, :end_time, presence: true
  validates :purpose, presence: true, length: { maximum: 255 }
  validates :status, presence: true,
            inclusion: { in: %w[pending confirmed cancelled completed no_show in_progress] }
  validates :approval_status, 
            inclusion: { in: %w[pending approved rejected auto_approved] }
  validates :priority, inclusion: { in: %w[low normal high urgent] }
  validates :attendee_count, numericality: { greater_than: 0 }, allow_blank: true
  validate :end_time_after_start_time
  validate :booking_within_allowed_range
  validate :no_conflicts_on_create, on: :create
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :active, -> { where(status: ['confirmed', 'in_progress']) }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_bookable, ->(type, id) { where(bookable_type: type, bookable_id: id) }
  scope :upcoming, -> { where('start_time > ?', Time.current).order(:start_time) }
  scope :past, -> { where('end_time < ?', Time.current).order(start_time: :desc) }
  scope :current, -> { where('start_time <= ? AND end_time > ?', Time.current, Time.current) }
  scope :requires_approval, -> { where(approval_status: 'pending') }
  scope :by_date_range, ->(start_date, end_date) { 
    where('start_time >= ? AND end_time <= ?', start_date, end_date) 
  }
  scope :for_room, -> { where(bookable_type: 'Room') }
  scope :for_equipment, -> { where(bookable_type: 'Equipment') }
  
  before_validation :generate_booking_reference, on: :create
  before_validation :calculate_total_cost
  before_create :check_for_conflicts
  after_create :update_bookable_status
  after_update :handle_status_changes
  
  def duration_hours
    ((end_time - start_time) / 1.hour).round(2)
  end
  
  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end
  
  def active?
    %w[confirmed in_progress].include?(status)
  end
  
  def can_be_cancelled?
    %w[pending confirmed].include?(status) && start_time > Time.current
  end
  
  def can_be_modified?
    status == 'pending' || (status == 'confirmed' && start_time > 1.hour.from_now)
  end
  
  def requires_approval?
    bookable.try(:requires_approval?) || false
  end
  
  def approved?
    approval_status == 'approved' || approval_status == 'auto_approved'
  end
  
  def pending_approval?
    approval_status == 'pending'
  end
  
  # Status management
  def confirm!
    return false unless status == 'pending'
    return false if requires_approval? && !approved?
    
    update!(status: 'confirmed')
  end
  
  def cancel!(reason = nil)
    return false unless can_be_cancelled?
    
    update!(
      status: 'cancelled',
      notes: [notes, "Cancelled: #{reason}"].compact.join("\n")
    )
  end
  
  def check_in!
    return false unless status == 'confirmed'
    return false if start_time > Time.current
    
    update!(status: 'in_progress', check_in_time: Time.current)
  end
  
  def check_out!
    return false unless status == 'in_progress'
    
    update!(status: 'completed', check_out_time: Time.current)
  end
  
  def mark_no_show!
    return false unless status == 'confirmed'
    return false if start_time > Time.current
    
    update!(status: 'no_show')
  end
  
  # Approval management
  def approve!(approver)
    return false unless approval_status == 'pending'
    
    update!(
      approval_status: 'approved',
      approved_by: approver,
      approved_at: Time.current,
      status: 'confirmed'
    )
  end
  
  def reject!(approver, reason = nil)
    return false unless approval_status == 'pending'
    
    update!(
      approval_status: 'rejected',
      approved_by: approver,
      approved_at: Time.current,
      approval_notes: reason,
      status: 'cancelled'
    )
  end
  
  # Conflict detection
  def has_conflicts?
    conflicts_as_primary.where(resolution_status: 'unresolved').any? ||
    conflicts_as_conflicting.where(resolution_status: 'unresolved').any?
  end
  
  def all_conflicts
    ResourceConflict.where('primary_booking_id = ? OR conflicting_booking_id = ?', id, id)
  end
  
  def unresolved_conflicts
    all_conflicts.where(resolution_status: 'unresolved')
  end
  
  def detect_conflicts
    overlapping_bookings = ResourceBooking
      .where(bookable: bookable)
      .where.not(id: id)
      .where(status: ['confirmed', 'pending', 'in_progress'])
      .where('start_time < ? AND end_time > ?', end_time, start_time)
    
    overlapping_bookings.each do |conflicting_booking|
      ResourceConflict.find_or_create_by(
        primary_booking: self,
        conflicting_booking: conflicting_booking
      ) do |conflict|
        conflict.conflict_type = 'time_overlap'
        conflict.severity = calculate_conflict_severity(conflicting_booking)
        conflict.detected_at = Time.current
      end
    end
  end
  
  # Recurring bookings
  def recurring?
    recurrence.present? && recurrence.is_a?(Hash) && recurrence['enabled']
  end
  
  def recurrence_pattern
    return nil unless recurring?
    recurrence['pattern'] # daily, weekly, monthly
  end
  
  def create_recurring_instances(end_date)
    return [] unless recurring?
    
    instances = []
    pattern = recurrence['pattern']
    interval = recurrence['interval'] || 1
    current_start = start_time
    
    while current_start <= end_date
      case pattern
      when 'daily'
        current_start += interval.days
      when 'weekly'
        current_start += interval.weeks
      when 'monthly'
        current_start += interval.months
      else
        break
      end
      
      break if current_start > end_date
      
      duration = end_time - start_time
      instance = dup
      instance.start_time = current_start
      instance.end_time = current_start + duration
      instance.recurrence = nil # Don't make instances recurring
      
      if instance.save
        instances << instance
      end
    end
    
    instances
  end
  
  # Cost calculation
  def calculate_cost
    return 0 unless bookable.respond_to?(:hourly_rate) && bookable.hourly_rate
    
    hours = duration_hours
    bookable.hourly_rate * hours
  end
  
  # Notifications
  def send_confirmation_email
    # Placeholder for email notification
    puts "Sending confirmation email for booking #{booking_reference}"
  end
  
  def send_reminder(hours_before = 24)
    # Placeholder for reminder notification
    puts "Sending reminder for booking #{booking_reference}"
  end
  
  # Search and filtering
  def self.search(query)
    return all if query.blank?
    
    joins(:user)
      .where('resource_bookings.purpose ILIKE ? OR resource_bookings.booking_reference ILIKE ? OR users.email ILIKE ?',
             "%#{query}%", "%#{query}%", "%#{query}%")
  end
  
  def self.overlapping(start_time, end_time)
    where('start_time < ? AND end_time > ?', end_time, start_time)
  end
  
  private
  
  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    
    errors.add(:end_time, 'must be after start time') if end_time <= start_time
  end
  
  def booking_within_allowed_range
    return unless bookable && start_time
    
    if bookable.respond_to?(:advance_booking_days)
      max_advance = bookable.advance_booking_days.days.from_now
      errors.add(:start_time, 'is too far in the future') if start_time > max_advance
    end
    
    if bookable.respond_to?(:max_booking_duration_hours)
      max_duration = bookable.max_booking_duration_hours.hours
      errors.add(:end_time, 'exceeds maximum booking duration') if duration_hours > bookable.max_booking_duration_hours
    end
  end
  
  def no_conflicts_on_create
    return unless bookable && start_time && end_time
    return if status == 'cancelled'
    
    conflicts = ResourceBooking
      .where(bookable: bookable)
      .where(status: ['confirmed', 'in_progress'])
      .where('start_time < ? AND end_time > ?', end_time, start_time)
    
    errors.add(:base, 'This resource is already booked for the selected time') if conflicts.any?
  end
  
  def generate_booking_reference
    return if booking_reference.present?
    
    self.booking_reference = \"BK#{Time.current.to_i}#{rand(1000..9999)}\"
  end
  
  def calculate_total_cost
    self.total_cost = calculate_cost
  end
  
  def check_for_conflicts
    detect_conflicts if status != 'cancelled'
  end
  
  def update_bookable_status
    return unless bookable.respond_to?(:update_availability_status)
    bookable.update_availability_status
  end
  
  def handle_status_changes
    if status_changed?
      case status
      when 'confirmed'
        send_confirmation_email
      when 'cancelled'
        # Release the resource
        update_bookable_status
      when 'completed'
        # Record completion
      end
    end
  end
  
  def calculate_conflict_severity(other_booking)
    return 'critical' if other_booking.status == 'confirmed' && other_booking.priority == 'urgent'
    return 'high' if other_booking.status == 'confirmed'
    return 'medium' if other_booking.status == 'pending'
    'low'
  end
end
