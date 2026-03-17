class SubmissionsController < ApplicationController
  before_action :set_assignment, only: [:index, :new, :create, :show, :edit, :update]
  before_action :set_submission, only: [:show, :edit, :update]
  before_action :authenticate_user!
  before_action :authorize_teacher!, only: [:index, :edit, :update]
  before_action :authorize_student!, only: [:new, :create]

  # GET /assignments/:assignment_id/submissions
  def index
    # Teacher views all submissions for their assignment
    unless @assignment.user_id == current_user.id
      redirect_to root_path, alert: "You are not authorized to view these submissions."
      return
    end
    
    @submissions = @assignment.submissions.includes(:user, documents_attachments: :blob)
                              .order(submitted_at: :desc)
  end

  # GET /assignments/:assignment_id/submissions/new
  def new
    @submission = @assignment.submissions.new
  end

  # POST /assignments/:assignment_id/submissions
  def create
    # Check if student already has a submission
    existing_submission = @assignment.submissions.find_by(user_id: current_user.id)
    
    if existing_submission && !@assignment.allow_resubmission
      redirect_to assignment_submission_path(@assignment, existing_submission), 
                  alert: 'You have already submitted this assignment. Resubmissions are not allowed.'
      return
    end

    # If resubmission is allowed, update existing submission
    if existing_submission && @assignment.allow_resubmission
      @submission = existing_submission
      @submission.assign_attributes(submission_params)
    else
      @submission = @assignment.submissions.new(submission_params)
      @submission.user = current_user
    end

    # Set submission status and timestamp
    @submission.status = 'submitted'
    @submission.submitted_at = Time.current

    if @submission.save
      # Notify teacher of new submission
      Notification.notify_submission_received(@assignment.user, @submission)
      
      redirect_to assignment_submission_path(@assignment, @submission), 
                  notice: existing_submission ? 'Assignment resubmitted successfully!' : 'Assignment submitted successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /assignments/:assignment_id/submissions/:id
  def show
    # Students can view their own submission, teachers can view all
    unless current_user.teacher? || @submission.user_id == current_user.id
      redirect_to root_path, alert: "You are not authorized to view this submission."
      return
    end
  end

  # GET /assignments/:assignment_id/submissions/:id/edit
  def edit
    # Only teacher who owns the assignment can grade
    unless @assignment.user_id == current_user.id
      redirect_to root_path, alert: "You are not authorized to grade this submission."
      return
    end
  end

  # PATCH/PUT /assignments/:assignment_id/submissions/:id
  def update
    # Only teacher who owns the assignment can grade
    unless @assignment.user_id == current_user.id
      redirect_to root_path, alert: "You are not authorized to grade this submission."
      return
    end

    @submission.graded_by = current_user if grading_params[:grade].present?
    
    respond_to do |format|
      if @submission.update(grading_params)
        # Notify student of grading if grade was given
        if grading_params[:grade].present?
          Notification.notify_assignment_graded(@submission.user, @submission)
        end
        
        format.html { redirect_to assignment_submissions_path(@assignment), notice: 'Grade and feedback submitted successfully.' }
        format.json { render json: { success: true, submission: submission_json(@submission), message: 'Grade saved successfully!' } }
      else
        format.html { render :edit }
        format.json { render json: { success: false, errors: @submission.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_submission
    @submission = @assignment.submissions.find(params[:id])
  end

  def set_assignment
    @assignment = Assignment.find(params[:assignment_id])
  end

  def submission_params
    params.require(:submission).permit(:content, documents: [])
  end

  def grading_params
    params.require(:submission).permit(:grade, :feedback)
  end

  def submission_json(submission)
    {
      id: submission.id,
      grade: submission.grade,
      feedback: submission.feedback,
      percentage_grade: submission.percentage_grade&.round(1),
      letter_grade: submission.letter_grade,
      graded_at: submission.graded_at&.strftime("%B %d, %Y at %I:%M %p"),
      graded_by: submission.graded_by&.full_name,
      status: submission.status
    }
  end

  def authorize_teacher!
    unless current_user.teacher?
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
  end

  def authorize_student!
    if current_user.teacher?
      redirect_to root_path, alert: "Teachers cannot submit assignments."
    end
  end
end
