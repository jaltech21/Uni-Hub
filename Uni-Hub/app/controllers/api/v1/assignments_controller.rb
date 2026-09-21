module Api
  module V1
    class AssignmentsController < BaseController
      before_action :set_assignment, only: [:show, :submit, :submissions]

      def index
        assignments = if current_user.teacher?
                        current_user.created_assignments.includes(:submissions, :user, :schedule)
                      else
                        current_user.visible_assignments.includes(:submissions, :user, :schedule)
                      end
        assignments = assignments.order(due_date: :asc)

        render_success(assignments.map { |a| serialize_assignment(a) })
      end

      def my_submissions
        submissions = current_user.submissions.includes(:assignment).order(submitted_at: :desc)
        render_success(submissions.map { |s| serialize_submission(s) })
      end

      def show
        return render_forbidden unless assignment_visible_to?(current_user, @assignment)
        render_success(serialize_assignment(@assignment, detail: true))
      end

      def submit
        return render_forbidden unless @assignment.visible_to?(current_user)

        existing = @assignment.submissions.find_or_initialize_by(user: current_user)
        existing.content = submission_params[:content]
        existing.status = "submitted"
        existing.submitted_at = Time.current

        if existing.save
          render_success(serialize_submission(existing), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: existing.errors.messages
          )
        end
      end

      def submissions
        if current_user.teacher? || current_user.tutor?
          return render_forbidden unless @assignment.user_id == current_user.id
        else
          return render_forbidden
        end

        collection = @assignment.submissions.includes(:user).order(submitted_at: :desc)
        render_success(collection.map { |s| serialize_submission(s) })
      end

      private

      def set_assignment
        @assignment = Assignment.find(params[:id])
      end

      def submission_params
        params.expect(submission: {}).permit(:content)
      end

      def assignment_visible_to?(user, assignment)
        return true if user.teacher? || user.admin?
        assignment.visible_to?(user)
      end

      def serialize_assignment(assignment, detail: false)
        payload = {
          id: assignment.id,
          title: assignment.title,
          description: assignment.description,
          due_date: assignment.due_date,
          points: assignment.points,
          category: assignment.category,
          teacher_id: assignment.user_id,
          course_id: assignment.schedule_id,
          course_name: assignment.schedule&.course || assignment.course_name,
          created_at: assignment.created_at,
          updated_at: assignment.updated_at
        }
        if detail
          payload[:allow_resubmission] = assignment.allow_resubmission
          payload[:grading_criteria] = assignment.grading_criteria
          payload[:my_submission] = current_user.submissions.find_by(assignment: assignment)&.content
        end
        payload[:status] = assignment_status(assignment)
        payload
      end

      def assignment_status(assignment)
        if current_user.teacher? || current_user.admin?
          return "graded" if assignment.graded_count.positive?
          return "submitted" if assignment.submitted_count.positive?
          return "pending"
        end

        submission = assignment.submissions.find_by(user: current_user)
        return "pending" unless submission
        submission.status == "graded" || submission.grade.present? ? "graded" : "submitted"
      end

      def serialize_submission(submission)
        {
          id: submission.id,
          student_id: submission.user_id,
          student_name: submission.user&.full_name,
          assignment_id: submission.assignment_id,
          content: submission.content,
          grade: submission.grade,
          feedback: submission.feedback,
          status: submission.status,
          submitted_at: submission.submitted_at,
          graded_at: submission.graded_at,
          created_at: submission.created_at,
          updated_at: submission.updated_at
        }
      end
    end
  end
end