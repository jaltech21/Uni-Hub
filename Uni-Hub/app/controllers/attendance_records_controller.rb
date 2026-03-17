class AttendanceRecordsController < ApplicationController
  #before_action :set_attendance_list
  before_action :authenticate_user!
  before_action :set_attendance_list, only: [:index, :create] 

  def new_check_in
    # This is the page with the form for the student to enter the code
    @attendance_record = AttendanceRecord.new
  end

  def create_check_in
    # 1. Find the AttendanceList by the submitted code
    submitted_code = params[:attendance_record][:code]
    @attendance_list = AttendanceList.find_by(current_attendance_code: submitted_code)
    
    # 2. Check if the code is valid (it must match a code valid in the last 2 minutes)
    unless @attendance_list && @attendance_list.verify_attendance_code(submitted_code)
      redirect_to new_check_in_path, alert: "Invalid or expired attendance code." and return
    end

    # 3. Create or update the AttendanceRecord
    @record = @attendance_list.attendance_records.find_or_initialize_by(user: current_user)
    
    if @record.new_record? || @record.created_at < 5.minutes.ago 
      # Only allow a new record or re-mark after a cool-down period
      @record.status = 'present' # Assuming your model uses 'status'
      if @record.save
        redirect_to dashboard_path, notice: "You are marked present for '#{@attendance_list.title}'!"
      else
        redirect_to new_check_in_path, alert: "Could not record attendance. Please try again."
      end
    else
       redirect_to dashboard_path, notice: "You have already checked in for this list."
    end
  end

  def index
    @students = User.where(role: 'student')
    @records = @attendance_list.attendance_records.index_by(&:user_id)
  end

  def create
    @user = User.find(params[:user_id])
    @record = @attendance_list.attendance_records.find_or_initialize_by(user_id: @user.id)
    @record.present = params[:present] == 'true'
    @record.save
    head :ok
  end

  private

  def set_attendance_list
    @attendance_list = AttendanceList.find(params[:attendance_list_id])
  end
end
