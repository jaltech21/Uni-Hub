module Api
  module V1
    class QuizzesController < BaseController
      before_action :set_quiz, only: [:show, :submit, :results]

      def index
        quizzes = Quiz.published.includes(:user, :quiz_questions).recent
        render_success(quizzes.map { |q| serialize_quiz(q) })
      end

      def show
        render_success(serialize_quiz(@quiz, with_questions: true))
      end

      def submit
        attempt = user_quiz_attempt
        return render_error("You already have an active attempt for this quiz", status: :unprocessable_entity, code: "ACTIVE_ATTEMPT") if attempt&.in_progress?

        attempt ||= QuizAttempt.create!(quiz: @quiz, user: current_user, started_at: Time.current)
        attempt.submit!(answers_params)
        render_success(serialize_results(attempt), status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error("Validation failed", status: :unprocessable_entity, code: "VALIDATION_ERROR", errors: e.record.errors.messages)
      end

      def results
        attempt = current_user.quiz_attempts.where(quiz: @quiz).completed.order(created_at: :desc).first
        return render_error("No completed attempt found", status: :not_found, code: "NOT_FOUND") unless attempt
        render_success(serialize_results(attempt))
      end

      private

      def set_quiz
        @quiz = Quiz.find(params[:id])
      end

      def user_quiz_attempt
        current_user.quiz_attempts.find_by(quiz: @quiz)
      end

      def answers_params
        params[:answers] || params[:quiz]&.to_unsafe_h&.fetch(:answers, {}) || {}
      end

      def serialize_quiz(quiz, with_questions: false)
        payload = {
          id: quiz.id,
          title: quiz.title,
          description: quiz.description,
          time_limit: quiz.time_limit,
          difficulty: quiz.difficulty,
          total_questions: quiz.total_questions,
          created_by: quiz.user_id,
          created_at: quiz.created_at,
          updated_at: quiz.updated_at,
          attempted: quiz.attempted_by?(current_user),
          best_score: quiz.best_score_for(current_user)
        }
        if with_questions
          payload[:questions] = quiz.quiz_questions.ordered.map do |q|
            {
              id: q.id,
              question_text: q.question_text,
              question_type: q.question_type,
              options: q.formatted_options,
              points: q.points
            }
          end
        end
        payload
      end

      def serialize_results(attempt)
        {
          attempt_id: attempt.id,
          score: attempt.score,
          correct_answers: attempt.correct_answers,
          total_questions: attempt.total_questions,
          passed: attempt.passed?,
          completed_at: attempt.completed_at
        }
      end
    end
  end
end