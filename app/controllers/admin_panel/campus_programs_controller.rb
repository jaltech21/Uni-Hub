class Admin::CampusProgramsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_campus
  before_action :set_campus_program, only: [:show, :edit, :update, :destroy, :enroll_student, :statistics]
  
  def index
    @campus_programs = @campus.campus_programs
                             .includes(:department, :program_director)
                             .page(params[:page])
                             .per(20)
    
    # Filters
    @campus_programs = @campus_programs.by_level(params[:level]) if params[:level].present?
    @campus_programs = @campus_programs.by_delivery(params[:delivery]) if params[:delivery].present?
    @campus_programs = @campus_programs.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    @departments = @campus.departments
    @program_statistics = {
      total_programs: @campus.campus_programs.count,
      active_programs: @campus.campus_programs.active.count,
      total_enrollment: @campus.campus_programs.sum(:current_enrollment),
      programs_by_level: @campus.campus_programs.group(:degree_level).count
    }
  end
  
  def show
    @enrollments = @campus_program.program_enrollments.includes(:user).limit(20)
    @program_courses = @campus_program.program_courses.includes(:course)
    @statistics = @campus_program.program_statistics
    @financial_summary = @campus_program.financial_summary
    @similar_programs = @campus_program.similar_programs(3)
  end
  
  def new
    @campus_program = @campus.campus_programs.build
    @departments = @campus.departments
    @potential_directors = User.joins(:department)
                              .where(department: { campus_id: @campus.id })
                              .where(role: ['instructor', 'admin'])
  end
  
  def create
    @campus_program = @campus.campus_programs.build(campus_program_params)
    
    if @campus_program.save
      redirect_to admin_campus_campus_program_path(@campus, @campus_program),
                  notice: 'Program was successfully created.'
    else
      @departments = @campus.departments
      @potential_directors = User.joins(:department)
                                .where(department: { campus_id: @campus.id })
                                .where(role: ['instructor', 'admin'])
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @departments = @campus.departments
    @potential_directors = User.joins(:department)
                              .where(department: { campus_id: @campus.id })
                              .where(role: ['instructor', 'admin'])
  end
  
  def update
    if @campus_program.update(campus_program_params)
      redirect_to admin_campus_campus_program_path(@campus, @campus_program),
                  notice: 'Program was successfully updated.'
    else
      @departments = @campus.departments
      @potential_directors = User.joins(:department)
                                .where(department: { campus_id: @campus.id })
                                .where(role: ['instructor', 'admin'])
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @campus_program.program_enrollments.active.any?
      redirect_to admin_campus_campus_program_path(@campus, @campus_program),
                  alert: 'Cannot delete program with active enrollments.'
    else
      @campus_program.destroy
      redirect_to admin_campus_campus_programs_path(@campus),
                  notice: 'Program was successfully deleted.'
    end
  end
  
  def enroll_student
    user = User.find(params[:user_id])
    
    if @campus_program.enroll_student(user)
      render json: { 
        success: true, 
        message: "#{user.full_name} enrolled successfully",
        enrollment_count: @campus_program.current_enrollment
      }
    else
      render json: { 
        success: false, 
        message: "Enrollment failed - program may be at capacity"
      }
    end
  end
  
  def withdraw_student
    user = User.find(params[:user_id])
    
    if @campus_program.withdraw_student(user)
      render json: { 
        success: true, 
        message: "#{user.full_name} withdrawn successfully",
        enrollment_count: @campus_program.current_enrollment
      }
    else
      render json: { 
        success: false, 
        message: "Withdrawal failed"
      }
    end
  end
  
  def graduate_student
    user = User.find(params[:user_id])
    
    if @campus_program.graduate_student(user)
      render json: { 
        success: true, 
        message: "#{user.full_name} graduated successfully",
        enrollment_count: @campus_program.current_enrollment
      }
    else
      render json: { 
        success: false, 
        message: "Graduation processing failed"
      }
    end
  end
  
  def statistics
    render json: @campus_program.program_statistics.merge(
      financial_summary: @campus_program.financial_summary,
      enrollment_trends: @campus_program.enrollment_by_semester,
      graduation_trends: @campus_program.graduation_by_semester
    )
  end
  
  def manage_courses
    @available_courses = @campus_program.department.courses.active
    @program_courses = @campus_program.program_courses.includes(:course)
    
    if request.post?
      course = Course.find(params[:course_id])
      course_type = params[:course_type] || 'required'
      credits = params[:credits]&.to_i
      
      if @campus_program.add_course(course, course_type: course_type, credits: credits)
        redirect_to manage_courses_admin_campus_campus_program_path(@campus, @campus_program),
                    notice: 'Course added to program successfully.'
      else
        redirect_to manage_courses_admin_campus_campus_program_path(@campus, @campus_program),
                    alert: 'Failed to add course to program.'
      end
    end
  end
  
  def remove_course
    program_course = @campus_program.program_courses.find(params[:program_course_id])
    program_course.destroy
    
    redirect_to manage_courses_admin_campus_campus_program_path(@campus, @campus_program),
                notice: 'Course removed from program successfully.'
  end
  
  private
  
  def set_campus
    @campus = Campus.find(params[:campus_id])
  end
  
  def set_campus_program
    @campus_program = @campus.campus_programs.find(params[:id])
  end
  
  def campus_program_params
    params.require(:campus_program).permit(
      :name, :code, :department_id, :program_director_id, :degree_level,
      :duration_months, :credits_required, :description, :delivery_method,
      :tuition_per_credit, :max_enrollment, :active, :accreditation_body,
      :last_accredited, :next_review_date, :admission_requirements,
      program_outcomes: []
    )
  end
  
  def ensure_admin_access
    redirect_to root_path unless current_user.admin? || current_user.campus_admin?
  end
end