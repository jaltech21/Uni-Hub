class QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_quiz, only: [:show, :edit, :update, :destroy, :take, :submit_quiz]
  before_action :authorize_owner, only: [:edit, :update, :destroy]
  before_action :check_active_attempt, only: [:take]
  before_action :set_rate_limit_info, only: [:generate]
  
  # GET /quizzes
  def index
    # Get department context: prefer explicit param, fallback to current_department
    @filter_department = if params[:department_id].present?
      Department.find_by(id: params[:department_id])
    else
      current_department
    end
    
    # Use Pundit scope to get authorized quizzes
    base = policy_scope(Quiz).includes(:quiz_questions, :quiz_attempts)
    @quizzes = @filter_department ? base.by_department(@filter_department).recent : base.recent
    @attempted_quizzes = current_user.quiz_attempts.includes(:quiz).completed.recent.limit(10)
  end
  
  # GET /quizzes/:id
  def show
    authorize @quiz
    @attempts = @quiz.quiz_attempts.where(user: current_user).completed.recent
    @best_score = @quiz.best_score_for(current_user)
    @avg_score = @quiz.average_score
  end
  
  # GET /quizzes/new
  def new
    @quiz = Quiz.new
    authorize @quiz
    @notes = current_user.notes.order(updated_at: :desc)
  end
  
  # POST /quizzes
  def create
    @quiz = current_user.quizzes.build(quiz_params)
    authorize @quiz
    
    if @quiz.save
      redirect_to quiz_path(@quiz), notice: 'Quiz created successfully. Add questions to get started.'
    else
      @notes = current_user.notes.order(updated_at: :desc)
      render :new, status: :unprocessable_entity
    end
  end
  
  # GET /quizzes/:id/edit
  def edit
    authorize @quiz
    @notes = current_user.notes.order(updated_at: :desc)
  end
  
  # PATCH/PUT /quizzes/:id
  def update
    authorize @quiz
    if @quiz.update(quiz_params)
      redirect_to quiz_path(@quiz), notice: 'Quiz updated successfully.'
    else
      @notes = current_user.notes.order(updated_at: :desc)
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /quizzes/:id
  def destroy
    authorize @quiz
    @quiz.destroy
    redirect_to quizzes_path, notice: 'Quiz deleted successfully.'
  end
  
  # GET /quizzes/generate
  def generate
    authorize Quiz, :generate?
    @notes = current_user.notes.where("LENGTH(CAST(content AS TEXT)) >= ?", 200).order(updated_at: :desc)
    
    if @notes.empty?
      redirect_to notes_path, alert: 'You need notes with at least 200 characters to generate a quiz.'
    end
  end
  
  # POST /quizzes/generate_from_note
  def generate_from_note
    authorize Quiz, :generate_from_note?
    
    # Validate note_id parameter
    if params[:note_id].blank?
      redirect_to generate_quizzes_path, alert: 'Please select a note to generate quiz from.' and return
    end

    note = current_user.notes.find(params[:note_id])
    
    unless note.sufficient_for_quiz?
      redirect_to generate_quizzes_path, alert: 'Note content is too short. Need at least 200 characters.' and return
    end
    
    # Get parameters
    question_count = params[:question_count].to_i.clamp(3, 20)
    question_type = params[:question_type].presence || 'mixed'
    difficulty = params[:difficulty].presence || 'medium'
    
    Rails.logger.info("Generating quiz: #{question_count} questions, type: #{question_type}, difficulty: #{difficulty}")
    
    # Generate questions using OpenAI
    result = AiServiceFactory.provider.generate_questions(
      note.plain_text_content,
      question_type: question_type.to_sym,
      count: question_count,
      difficulty: difficulty.to_sym,
      user_id: current_user.id
    )
    
    if result[:success]
      Rails.logger.info("Quiz generation successful, creating quiz...")
      
      # Create quiz
      quiz = current_user.quizzes.create!(
        title: "Quiz: #{note.title}",
        description: "AI-generated quiz from your note (#{question_type} questions, #{difficulty} difficulty)",
        note: note,
        difficulty: difficulty,
        status: 'draft'
      )
      
      # Create questions
      result[:questions].each_with_index do |q_data, index|
        quiz.quiz_questions.create!(
          question_type: q_data[:type],
          question_text: q_data[:question],
          options: q_data[:options] || [],
          correct_answer: q_data[:correct_answer],
          explanation: q_data[:explanation],
          position: index + 1,
          points: 1
        )
      end
      
      quiz.update_total_questions!
      
      Rails.logger.info("Quiz created successfully: #{quiz.id}")
      redirect_to quiz_path(quiz), notice: "🎉 Successfully generated #{question_count} questions! Review and publish when ready."
    elsif result[:rate_limited]
      flash[:alert] = result[:error]
      redirect_to generate_quizzes_path
    else
      Rails.logger.error("Quiz generation failed: #{result[:error]}")
      flash[:alert] = result[:error]
      redirect_to generate_quizzes_path
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to generate_quizzes_path, alert: 'Note not found. Please select a valid note.'
  rescue StandardError => e
    Rails.logger.error "Quiz generation error: #{e.message}"
    redirect_to generate_quizzes_path, alert: 'An error occurred while generating the quiz.'
  end
  
  # GET /quizzes/:id/take
  def take
    authorize @quiz, :take?
    
    unless @quiz.status == 'published'
      redirect_to quiz_path(@quiz), alert: 'This quiz is not published yet.' and return
    end
    
    if @quiz.quiz_questions.empty?
      redirect_to quiz_path(@quiz), alert: 'This quiz has no questions.' and return
    end
    
    # Create new attempt
    @attempt = @quiz.quiz_attempts.create!(
      user: current_user,
      started_at: Time.current
    )
    
    session[:quiz_attempt_id] = @attempt.id
    @questions = @quiz.quiz_questions.ordered
  end
  
  # POST /quizzes/:id/submit
  def submit_quiz
    authorize @quiz, :submit_quiz?
    
    attempt_id = session[:quiz_attempt_id]
    
    unless attempt_id
      redirect_to quiz_path(@quiz), alert: 'No active quiz attempt found.' and return
    end
    
    @attempt = QuizAttempt.find_by(id: attempt_id, quiz: @quiz, user: current_user)
    
    unless @attempt
      redirect_to quiz_path(@quiz), alert: 'Quiz attempt not found.' and return
    end
    
    if @attempt.completed?
      redirect_to results_quiz_path(@quiz, attempt_id: @attempt.id), notice: 'Quiz already submitted.' and return
    end
    
    # Submit the quiz with answers
    @attempt.submit!(params[:answers] || {})
    session.delete(:quiz_attempt_id)
    
    redirect_to results_quiz_path(@quiz, attempt_id: @attempt.id), notice: 'Quiz submitted successfully!'
  end
  
  # GET /quizzes/:id/results
  def results
    @attempt = QuizAttempt.find_by(id: params[:attempt_id], quiz_id: params[:id], user: current_user)
    
    unless @attempt
      redirect_to quizzes_path, alert: 'Quiz attempt not found.' and return
    end
    
    @quiz = @attempt.quiz
    authorize @quiz, :results?
    @questions = @quiz.quiz_questions.ordered
  end
  
  # PATCH /quizzes/:id/publish
  def publish
    @quiz = current_user.quizzes.find(params[:id])
    authorize @quiz, :publish?
    
    if @quiz.quiz_questions.empty?
      redirect_to quiz_path(@quiz), alert: 'Cannot publish a quiz without questions.' and return
    end
    
    @quiz.publish!
    redirect_to quiz_path(@quiz), notice: 'Quiz published successfully!'
  rescue ActiveRecord::RecordNotFound
    redirect_to quizzes_path, alert: 'Quiz not found.'
  end
  
  private
  
  def set_quiz
    @quiz = Quiz.find(params[:id])
  end
  
  def authorize_owner
    authorize @quiz
  end
  
  def check_active_attempt
    active_attempt = QuizAttempt.find_by(quiz: @quiz, user: current_user, completed_at: nil)
    if active_attempt
      session[:quiz_attempt_id] = active_attempt.id
    end
  end
  
  def set_rate_limit_info
    provider = AiServiceFactory.provider
    @rate_limit_max = provider.max_requests_per_hour
    @rate_limit_remaining = provider.remaining_requests(current_user.id)
  end
  
  def quiz_params
    params.require(:quiz).permit(:title, :description, :note_id, :time_limit, :difficulty, :status)
  end
end
