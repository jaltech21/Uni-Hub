module Api
  module V1
    class SubmissionsController < BaseController
      before_action :set_submission

      def grade
        return render_forbidden unless current_user.teacher? || current_user.tutor?

        unless @submission.assignment.user_id == current_user.id
          return render_forbidden
        end

        if @submission.update(grade_params)
          NotificationService.create_notification(
            user: @submission.user,
            title: "Assignment Graded",
            message: "Your submission for #{@submission.assignment.title} has been graded.",
            notification_type: "assignment_graded",
            related_object: @submission
          )
          render_success(serialize_submission(@submission))
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: @submission.errors.messages
          )
        end
      end

      private

      def set_submission
        @submission = Submission.find(params[:id])
      end

      def grade_params
        params.expect(submission: {}).permit(:grade, :feedback)
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