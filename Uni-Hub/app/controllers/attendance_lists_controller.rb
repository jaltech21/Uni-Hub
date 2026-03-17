class AttendanceListsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_teacher # Applied to all actions (index, create, show, destroy, etc.)
  before_action :set_attendance_list, only: [:show, :edit, :update, :destroy]
  before_action :prevent_caching, only: [:refresh_code] 

  def index
    @attendance_lists = current_user.attendance_lists.order(created_at: :desc)
    @attendance_list = @attendance_lists.first
  end

  def new
    @attendance_list = current_user.attendance_lists.new
  end

  def edit
  end

  def create
    @attendance_list = current_user.attendance_lists.new(attendance_list_params)
    if @attendance_list.save
      redirect_to attendance_list_attendance_records_path(@attendance_list), notice: 'Attendance list was successfully created. Now, add records.'
    else
      render :new
    end
  end

  def show
  end

  def update
    if @attendance_list.update(attendance_list_params)
      redirect_to attendance_list_path(@attendance_list), notice: 'Attendance list was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # FIX: The destroy logic is correct. Added a status code for better Turbo/Hotwire compatibility.
  def destroy
    @attendance_list.destroy
    redirect_to attendance_lists_url, notice: 'Attendance list was successfully deleted.', status: :see_other
  end

  def refresh_code
    set_attendance_list # Ensure @attendance_list is set
    render layout: false
  end

  private

  # Set the attendance list, ensuring it belongs to the current user.
  def prevent_caching
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def set_attendance_list
    Rails.logger.info "Set Attendance List: Checking session and user details"
    Rails.logger.info "Session Loaded: \\#{session.loaded?}" # Log if the session is loaded
    Rails.logger.info "Current User: \\#{current_user.inspect}" # Log the current user

    @attendance_list = current_user.attendance_lists.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Attendance list not found or unauthorized access attempt by user: \\#{current_user&.id || 'Guest'}"
    redirect_to attendance_lists_url, alert: 'Attendance list not found or you are not authorized to access it.'
  end

  def attendance_list_params
    # FIX CONFIRMED: Only permitting title, description, and date (no secret_key/special_code is mass-assignable)
    params.require(:attendance_list).permit(:title, :description, :date)
  end

  def authorize_teacher
    Rails.logger.info "Authorize Teacher: Checking user authentication"
    Rails.logger.info "Request Type: \\#{request.method}" # Log the request type
    Rails.logger.info "Session Loaded: \\#{session.loaded?}" # Log if the session is loaded
    Rails.logger.info "Current User: \\#{current_user.inspect}" # Log the current user

    unless current_user&.teacher?
      Rails.logger.warn "Unauthorized access attempt by user: \\#{current_user&.id || 'Guest'}"
      redirect_to root_path, alert: 'You are not authorized to access this page.'
    end
  end
end