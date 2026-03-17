class AdminPanel::CoursesController < ApplicationController
  layout 'admin'
  before_action :authorize_admin!
  before_action :set_course, only: [:show, :edit, :update, :destroy, :toggle_active]

  # GET /admin/courses
  def index
    @courses = Course.includes(:department)
                     .order(active: :desc, code: :asc)
    
    # Filter by department if provided
    @courses = @courses.where(department_id: params[:department_id]) if params[:department_id].present?
    
    # Filter by status
    @courses = @courses.active if params[:status] == 'active'
    @courses = @courses.where(active: false) if params[:status] == 'inactive'
    
    @departments = Department.order(:name)
  end

  # GET /admin/courses/:id
  def show
    @schedules = Schedule.where(course: @course.full_code)
                         .includes(:instructor, :active_enrollments)
                         .order(created_at: :desc)
  end

  # GET /admin/courses/new
  def new
    @course = Course.new
    @departments = Department.active.order(:name)
  end

  # GET /admin/courses/:id/edit
  def edit
    @departments = Department.active.order(:name)
  end

  # POST /admin/courses
  def create
    @course = Course.new(course_params)
    
    if @course.save
      redirect_to admin_panel_course_path(@course), notice: 'Course created successfully.'
    else
      @departments = Department.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/courses/:id
  def update
    if @course.update(course_params)
      redirect_to admin_panel_course_path(@course), notice: 'Course updated successfully.'
    else
      @departments = Department.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/courses/:id
  def destroy
    if @course.course_schedules.exists?
      redirect_to admin_panel_course_path(@course), alert: 'Cannot delete course with existing schedules.'
    else
      @course.destroy
      redirect_to admin_panel_courses_path, notice: 'Course deleted successfully.'
    end
  end

  # PATCH /admin/courses/:id/toggle_active
  def toggle_active
    @course.update(active: !@course.active)
    redirect_to admin_panel_courses_path, notice: "Course #{@course.active? ? 'activated' : 'deactivated'} successfully."
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(
      :code,
      :name,
      :description,
      :department_id,
      :credits,
      :duration_weeks,
      :level,
      :delivery_method,
      :prerequisites,
      :tuition_cost,
      :max_students,
      :instructor_requirements,
      :active
    )
  end

  def authorize_admin!
    unless user_signed_in? && current_user.admin?
      redirect_to new_admin_session_path, alert: 'Please sign in with an admin account.'
    end
  end
end
