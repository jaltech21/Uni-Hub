class Admin::ResourceBookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :approve, :reject, :check_in, :check_out]
  
  def index
    @bookings = ResourceBooking.includes(:user, :bookable, :approved_by)
                              .page(params[:page])
                              .per(25)
    
    # Filters
    @bookings = @bookings.where(status: params[:status]) if params[:status].present?
    @bookings = @bookings.where(approval_status: params[:approval]) if params[:approval].present?
    @bookings = @bookings.where(bookable_type: params[:type]) if params[:type].present?
    @bookings = @bookings.by_user(params[:user_id]) if params[:user_id].present?
    @bookings = @bookings.where('booking_reference ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    # Date filtering
    if params[:date_from].present? && params[:date_to].present?
      @bookings = @bookings.by_date_range(params[:date_from], params[:date_to])
    elsif params[:view] == 'upcoming'
      @bookings = @bookings.upcoming
    elsif params[:view] == 'past'
      @bookings = @bookings.past
    end
    
    @statistics = {
      total: ResourceBooking.count,
      pending: ResourceBooking.pending.count,
      confirmed: ResourceBooking.confirmed.count,
      requires_approval: ResourceBooking.requires_approval.count,
      conflicts: ResourceConflict.unresolved.count
    }
  end
  
  def show
    @conflicts = @booking.all_conflicts.includes(:conflicting_booking, :resolved_by)
    @resource = @booking.bookable
  end
  
  def new
    @booking = ResourceBooking.new
    @rooms = Room.available
    @equipment = Equipment.available
    @users = User.all
  end
  
  def create
    @booking = ResourceBooking.new(booking_params)
    @booking.user = current_user unless booking_params[:user_id].present?
    
    if @booking.save
      redirect_to admin_resource_booking_path(@booking),
                  notice: 'Booking was successfully created.'
    else
      @rooms = Room.available
      @equipment = Equipment.available
      @users = User.all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @rooms = Room.all
    @equipment = Equipment.all
    @users = User.all
  end
  
  def update
    if @booking.update(booking_params)
      redirect_to admin_resource_booking_path(@booking),
                  notice: 'Booking was successfully updated.'
    else
      @rooms = Room.all
      @equipment = Equipment.all
      @users = User.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @booking.destroy
      redirect_to admin_resource_bookings_path,
                  notice: 'Booking was successfully deleted.'
    else
      redirect_to admin_resource_booking_path(@booking),
                  alert: 'Cannot delete this booking.'
    end
  end
  
  def approve
    if @booking.approve!(current_user)
      render json: { 
        success: true, 
        message: 'Booking approved successfully',
        status: @booking.status
      }
    else
      render json: { 
        success: false, 
        message: 'Failed to approve booking'
      }, status: :unprocessable_entity
    end
  end
  
  def reject
    reason = params[:reason] || 'No reason provided'
    
    if @booking.reject!(current_user, reason)
      render json: { 
        success: true, 
        message: 'Booking rejected successfully'
      }
    else
      render json: { 
        success: false, 
        message: 'Failed to reject booking'
      }, status: :unprocessable_entity
    end
  end
  
  def cancel
    reason = params[:reason]
    
    if @booking.cancel!(reason)
      redirect_to admin_resource_booking_path(@booking),
                  notice: 'Booking cancelled successfully.'
    else
      redirect_to admin_resource_booking_path(@booking),
                  alert: 'Cannot cancel this booking.'
    end
  end
  
  def check_in
    if @booking.check_in!
      render json: { 
        success: true, 
        message: 'Checked in successfully',
        check_in_time: @booking.check_in_time
      }
    else
      render json: { 
        success: false, 
        message: 'Check-in failed'
      }, status: :unprocessable_entity
    end
  end
  
  def check_out
    if @booking.check_out!
      render json: { 
        success: true, 
        message: 'Checked out successfully',
        check_out_time: @booking.check_out_time
      }
    else
      render json: { 
        success: false, 
        message: 'Check-out failed'
      }, status: :unprocessable_entity
    end
  end
  
  def check_availability
    start_time = Time.parse(params[:start_time]) rescue nil
    end_time = Time.parse(params[:end_time]) rescue nil
    bookable_type = params[:bookable_type]
    bookable_id = params[:bookable_id]
    
    if start_time && end_time && bookable_type && bookable_id
      bookable = bookable_type.constantize.find(bookable_id)
      available = bookable.available_at?(start_time, end_time)
      
      conflicts = ResourceBooking
        .where(bookable: bookable)
        .where(status: ['confirmed', 'in_progress'])
        .where('start_time < ? AND end_time > ?', end_time, start_time)
      
      render json: {
        available: available,
        conflicts: conflicts.map { |b| {
          id: b.id,
          reference: b.booking_reference,
          start_time: b.start_time,
          end_time: b.end_time,
          user: b.user.email
        }}
      }
    else
      render json: { error: 'Invalid parameters' }, status: :bad_request
    end
  end
  
  def calendar_data
    start_date = Date.parse(params[:start]) rescue 1.month.ago
    end_date = Date.parse(params[:end]) rescue 1.month.from_now
    
    bookings = ResourceBooking.by_date_range(start_date, end_date)
    
    if params[:bookable_type] && params[:bookable_id]
      bookings = bookings.by_bookable(params[:bookable_type], params[:bookable_id])
    end
    
    events = bookings.map do |booking|
      {
        id: booking.id,
        title: "#{booking.bookable_type}: #{booking.purpose}",
        start: booking.start_time.iso8601,
        end: booking.end_time.iso8601,
        backgroundColor: status_color(booking.status),
        borderColor: status_color(booking.status),
        url: admin_resource_booking_path(booking),
        extendedProps: {
          status: booking.status,
          user: booking.user.email,
          reference: booking.booking_reference
        }
      }
    end
    
    render json: events
  end
  
  def bulk_action
    booking_ids = params[:booking_ids] || []
    action = params[:action]
    
    bookings = ResourceBooking.where(id: booking_ids)
    results = { success: 0, failed: 0, messages: [] }
    
    bookings.each do |booking|
      case action
      when 'approve'
        if booking.approve!(current_user)
          results[:success] += 1
        else
          results[:failed] += 1
          results[:messages] << "Failed to approve #{booking.booking_reference}"
        end
      when 'reject'
        if booking.reject!(current_user, params[:reason])
          results[:success] += 1
        else
          results[:failed] += 1
          results[:messages] << "Failed to reject #{booking.booking_reference}"
        end
      when 'cancel'
        if booking.cancel!(params[:reason])
          results[:success] += 1
        else
          results[:failed] += 1
          results[:messages] << "Failed to cancel #{booking.booking_reference}"
        end
      end
    end
    
    render json: results
  end
  
  def statistics
    range = params[:range] || 'month'
    start_date = case range
                 when 'week' then 1.week.ago
                 when 'month' then 1.month.ago
                 when 'year' then 1.year.ago
                 else 1.month.ago
                 end
    
    bookings = ResourceBooking.where('created_at >= ?', start_date)
    
    stats = {
      total_bookings: bookings.count,
      confirmed: bookings.confirmed.count,
      pending: bookings.pending.count,
      cancelled: bookings.cancelled.count,
      completed: bookings.completed.count,
      revenue: bookings.where(status: ['confirmed', 'completed']).sum(:total_cost),
      by_resource_type: bookings.group(:bookable_type).count,
      by_status: bookings.group(:status).count,
      utilization_by_day: bookings.group_by_day(:start_time).count
    }
    
    render json: stats
  end
  
  private
  
  def set_booking
    @booking = ResourceBooking.find(params[:id])
  end
  
  def booking_params
    params.require(:resource_booking).permit(
      :user_id, :bookable_type, :bookable_id, :booking_type,
      :start_time, :end_time, :status, :purpose, :notes,
      :priority, :attendee_count, :contact_email, :contact_phone,
      :setup_required, setup_requirements: [], recurrence: {}
    )
  end
  
  def ensure_admin_access
    redirect_to root_path unless current_user.admin? || current_user.resource_manager?
  end
  
  def status_color(status)
    case status
    when 'confirmed' then '#28a745'
    when 'pending' then '#ffc107'
    when 'cancelled' then '#dc3545'
    when 'completed' then '#17a2b8'
    when 'in_progress' then '#007bff'
    else '#6c757d'
    end
  end
end