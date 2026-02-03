class ResourceConflict < ApplicationRecord
  belongs_to :primary_booking, class_name: 'ResourceBooking'
  belongs_to :conflicting_booking, class_name: 'ResourceBooking'
  belongs_to :resolved_by, class_name: 'User', optional: true
  
  validates :conflict_type, presence: true,
            inclusion: { in: %w[time_overlap double_booking capacity_exceeded priority_conflict resource_unavailable] }
  validates :severity, presence: true,
            inclusion: { in: %w[low medium high critical] }
  validates :resolution_status, presence: true,
            inclusion: { in: %w[unresolved resolved auto_resolved escalated] }
  
  # Scopes
  scope :unresolved, -> { where(resolution_status: 'unresolved') }
  scope :resolved, -> { where(resolution_status: ['resolved', 'auto_resolved']) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical, -> { where(severity: 'critical') }
  scope :recent, -> { where('detected_at >= ?', 7.days.ago) }
  scope :for_resource, ->(bookable_type, bookable_id) {
    joins(:primary_booking)
      .where(resource_bookings: { bookable_type: bookable_type, bookable_id: bookable_id })
  }
  
  before_create :populate_conflict_details
  after_create :notify_stakeholders
  
  def unresolved?
    resolution_status == 'unresolved'
  end
  
  def resolved?
    %w[resolved auto_resolved].include?(resolution_status)
  end
  
  def critical?
    severity == 'critical'
  end
  
  def resolve!(resolver, action, notes = nil)
    return false if resolved?
    
    update!(
      resolution_status: 'resolved',
      resolved_by: resolver,
      resolved_at: Time.current,
      resolution_action: action,
      resolution_notes: notes
    )
  end
  
  def auto_resolve!(action, notes = nil)
    return false if resolved?
    
    update!(
      resolution_status: 'auto_resolved',
      resolved_at: Time.current,
      resolution_action: action,
      resolution_notes: notes,
      auto_resolved: true
    )
  end
  
  def escalate!
    update!(
      resolution_status: 'escalated',
      severity: escalate_severity
    )
  end
  
  def conflict_summary
    {
      conflict_id: id,
      type: conflict_type,
      severity: severity,
      status: resolution_status,
      primary_booking: booking_summary(primary_booking),
      conflicting_booking: booking_summary(conflicting_booking),
      detected_at: detected_at,
      resolution: resolution_info
    }
  end
  
  def time_overlap_minutes
    return 0 unless primary_booking && conflicting_booking
    
    overlap_start = [primary_booking.start_time, conflicting_booking.start_time].max
    overlap_end = [primary_booking.end_time, conflicting_booking.end_time].min
    
    return 0 if overlap_end <= overlap_start
    
    ((overlap_end - overlap_start) / 60).to_i
  end
  
  def suggested_resolution
    case conflict_type
    when 'time_overlap'
      if primary_booking.status == 'pending' && conflicting_booking.status == 'confirmed'
        'cancel_primary'
      elsif primary_booking.priority == 'urgent' && conflicting_booking.priority != 'urgent'
        'cancel_conflicting'
      else
        'manual_review'
      end
    when 'double_booking'
      'cancel_lower_priority'
    when 'capacity_exceeded'
      'split_or_relocate'
    else
      'manual_review'
    end
  end
  
  def can_auto_resolve?
    return false if critical?
    return false if resolution_status != 'unresolved'
    
    suggested_resolution != 'manual_review'
  end
  
  def attempt_auto_resolution
    return false unless can_auto_resolve?
    
    case suggested_resolution
    when 'cancel_primary'
      if primary_booking.cancel!('Auto-cancelled due to conflict')
        auto_resolve!('cancelled_primary', 'Primary booking cancelled automatically')
      end
    when 'cancel_conflicting'
      if conflicting_booking.status == 'pending' && conflicting_booking.cancel!('Auto-cancelled due to higher priority conflict')
        auto_resolve!('cancelled_conflicting', 'Conflicting booking cancelled automatically')
      end
    else
      false
    end
  end
  
  def self.detect_and_create(booking)
    conflicts = []
    
    overlapping = ResourceBooking
      .where(bookable: booking.bookable)
      .where.not(id: booking.id)
      .where(status: ['confirmed', 'pending', 'in_progress'])
      .where('start_time < ? AND end_time > ?', booking.end_time, booking.start_time)
    
    overlapping.each do |other_booking|
      conflict = find_or_create_by(
        primary_booking: booking,
        conflicting_booking: other_booking
      ) do |c|
        c.conflict_type = 'time_overlap'
        c.severity = determine_severity(booking, other_booking)
        c.detected_at = Time.current
      end
      
      conflicts << conflict if conflict.persisted?
    end
    
    conflicts
  end
  
  def self.determine_severity(booking1, booking2)
    return 'critical' if booking1.status == 'confirmed' && booking2.status == 'confirmed'
    return 'critical' if booking1.priority == 'urgent' || booking2.priority == 'urgent'
    return 'high' if booking1.status == 'confirmed' || booking2.status == 'confirmed'
    return 'medium' if booking1.priority == 'high' || booking2.priority == 'high'
    'low'
  end
  
  def self.resolve_pending_conflicts
    unresolved.where(auto_resolved: false).find_each do |conflict|
      conflict.attempt_auto_resolution if conflict.can_auto_resolve?
    end
  end
  
  private
  
  def populate_conflict_details
    self.conflict_details = {
      primary_booking_id: primary_booking.id,
      primary_booking_ref: primary_booking.booking_reference,
      primary_user: primary_booking.user.email,
      primary_time: \"#{primary_booking.start_time} - #{primary_booking.end_time}\",
      conflicting_booking_id: conflicting_booking.id,
      conflicting_booking_ref: conflicting_booking.booking_reference,
      conflicting_user: conflicting_booking.user.email,
      conflicting_time: \"#{conflicting_booking.start_time} - #{conflicting_booking.end_time}\",
      overlap_minutes: time_overlap_minutes,
      resource: \"#{primary_booking.bookable_type} ##{primary_booking.bookable_id}\"
    }
  end
  
  def notify_stakeholders
    # Placeholder for notification logic
    puts \"Conflict detected: #{conflict_type} (#{severity})\"
  end
  
  def escalate_severity
    case severity
    when 'low' then 'medium'
    when 'medium' then 'high'
    when 'high' then 'critical'
    else severity
    end
  end
  
  def booking_summary(booking)
    {
      id: booking.id,
      reference: booking.booking_reference,
      user: booking.user.email,
      start_time: booking.start_time,
      end_time: booking.end_time,
      status: booking.status,
      priority: booking.priority
    }
  end
  
  def resolution_info
    return nil unless resolved?
    
    {
      resolved_by: resolved_by&.email,
      resolved_at: resolved_at,
      action: resolution_action,
      notes: resolution_notes,
      auto_resolved: auto_resolved
    }
  end
end
