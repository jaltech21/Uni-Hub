class Admin::DepartmentsController < Admin::BaseController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :toggle_active]

  def index
    authorize Department
    @departments = Department.includes(:users).order(:name)
                             .order(active: :desc, name: :asc)
    
    # Filter by active status if requested
    if params[:status] == 'inactive'
      @departments = @departments.inactive
    elsif params[:status] == 'active'
      @departments = @departments.active
    end
  end

  def show
    authorize @department
    @users = @department.users.includes(:teaching_departments)
    @content_stats = {
      assignments: Assignment.where(department: @department).count,
      notes: Note.where(department: @department).count,
      quizzes: Quiz.where(department: @department).count
    }
  end

  def new
    @department = Department.new
    authorize @department
  end

  def create
    @department = Department.new(department_params)
    authorize @department
    
    if @department.save
      redirect_to admin_department_path(@department), notice: "Department '#{@department.name}' was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @department
  end

  def update
    authorize @department
    if @department.update(department_params)
      redirect_to admin_department_path(@department), notice: "Department '#{@department.name}' was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @department
    if @department.users.any? || @department.teaching_users.any?
      redirect_to admin_department_path(@department), alert: 'Cannot delete department with assigned users. Please reassign users first.'
    else
      @department.destroy
      redirect_to admin_departments_path, notice: 'Department was successfully deleted.'
    end
  end

  def toggle_active
    authorize @department, :toggle_active?
    @department.update(active: !@department.active)

  private

  def set_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_departments_path, alert: "Department not found."
  end

  def department_params
    params.require(:department).permit(:name, :code, :description, :active, :university_id)
  end
end
