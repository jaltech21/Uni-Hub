class Admin::DepartmentsController < Admin::BaseController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :toggle_active]

  def index
    @departments = Department.all
    
    # Apply search filter
    if params[:q].present?
      @departments = @departments.where("name ILIKE ? OR code ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    # Apply status filter
    case params[:status]
    when 'active'
      @departments = @departments.active
    when 'inactive'
      @departments = @departments.inactive
    end
    
    @departments = @departments.ordered
  end

  def show
  end

  def new
    @department = Department.new
  end

  def create
    @department = Department.new(department_params)
    
    if @department.save
      AdminAuditLog.log(
        user: current_user,
        action: 'create',
        resource_type: 'Department',
        resource_id: @department.id,
        description: "Created department: #{@department.name}"
      )
      redirect_to admin_departments_path, notice: 'Department was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @department.update(department_params)
      AdminAuditLog.log(
        user: current_user,
        action: 'update',
        resource_type: 'Department',
        resource_id: @department.id,
        description: "Updated department: #{@department.name}"
      )
      redirect_to admin_departments_path, notice: 'Department was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    department_name = @department.name
    
    if @department.destroy
      AdminAuditLog.log(
        user: current_user,
        action: 'destroy',
        resource_type: 'Department',
        resource_id: @department.id,
        description: "Deleted department: #{department_name}"
      )
      redirect_to admin_departments_path, notice: 'Department was successfully deleted.'
    else
      redirect_to admin_departments_path, alert: "Cannot delete department: #{@department.errors.full_messages.join(', ')}"
    end
  end

  def toggle_active
    @department.update(active: !@department.active)
    
    AdminAuditLog.log(
      user: current_user,
      action: 'toggle_active',
      resource_type: 'Department',
      resource_id: @department.id,
      description: "#{@department.active? ? 'Activated' : 'Deactivated'} department: #{@department.name}"
    )
    
    redirect_to admin_departments_path, notice: "Department #{@department.active? ? 'activated' : 'deactivated'} successfully."
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :code, :description, :active, :university_id)
  end
end
