module Api
  module V1
    class AiController < BaseController
      before_action :require_teacher, only: [:tutor_report]

      CHAT_HISTORY_LIMIT = 20

      # ---- Summarization / study tools (any authenticated role) ----
      def summarize
        prompt = params[:text].to_s.strip
        text = prompt
        mode = params[:mode].presence || "assistant"

        if params.key?(:file)
          upload = params[:file]
          if upload.respond_to?(:empty?) && upload.empty?
            return render_error("The PDF upload was empty or was not received. Please select the file again.", status: :unprocessable_entity, code: "EMPTY_FILE")
          end

          unless upload.respond_to?(:content_type) && upload.respond_to?(:tempfile)
            return render_error("The PDF upload was empty or was not received. Please select the file again.", status: :unprocessable_entity, code: "EMPTY_FILE")
          end

          unless upload.respond_to?(:content_type) && (
            upload.content_type == "application/pdf" ||
            upload.original_filename.to_s.downcase.end_with?(".pdf")
          )
            return render_error("Only PDF files can be summarised.", status: :unprocessable_entity, code: "UNSUPPORTED_FILE")
          end

          text = PDF::Reader.new(upload.tempfile).pages.map(&:text).join("\n").strip
        end

        if text.blank?
          message = params[:file].present? ? "This PDF contains no selectable text. Upload a text-based PDF or paste its content." : "Add text or upload a PDF to summarise."
          return render_error(message, status: :unprocessable_entity, code: "TEXT_REQUIRED")
        end

        provider = AiServiceFactory.provider
        result =
          if mode == "hints"
            hints = provider.get_study_hints(text, user_id: current_user.id)
            if hints[:success] && Array(hints[:hints]).any?
              hints.merge(summary: Array(hints[:hints]).join("\n\n"))
            else
              hints.merge(success: false, error: "The AI returned no study guidance. Please try again.")
            end
          elsif mode == "questions"
            if text.length < 100
              return render_error("Add at least 100 characters of study material to generate questions.", status: :unprocessable_entity, code: "TEXT_TOO_SHORT")
            end
            questions = provider.generate_questions(
              text,
              question_type: :multiple_choice,
              count: 5,
              difficulty: :medium,
              user_id: current_user.id
            )
            if questions[:success]
              questions.merge(
                summary: Array(questions[:questions]).map.with_index do |question, index|
                  options = Array(question[:options]).each_with_index.map { |option, option_index| "#{('A'.ord + option_index).chr}. #{option}" }
                  "#{index + 1}. #{question[:question]}\n#{options.join("\n")}\nAnswer: #{question[:correct_answer]}\nExplanation: #{question[:explanation]}"
                end.join("\n\n")
              )
            else
              questions
            end
          elsif mode == "assistant"
            provider.answer_prompt(with_student_context(build_document_prompt(prompt, text)), user_id: current_user.id)
          else
            length = params[:length].presence&.to_sym || :medium
            if text.length < 100
              hints = provider.get_study_hints(text, user_id: current_user.id)
              if hints[:success] && Array(hints[:hints]).any?
                hints.merge(summary: Array(hints[:hints]).join("\n\n"))
              else
                hints.merge(success: false, error: "The AI returned no study guidance. Please try again.")
              end
            else
              provider.summarize_text(text, length: length, user_id: current_user.id)
            end
          end

        if result[:success]
          render_success({
            summary: result[:summary],
            source_length: text.length,
            source_word_count: text.split(/\s+/).length
          })
        elsif result[:rate_limited]
          render_error(result[:error], status: :too_many_requests, code: "RATE_LIMITED")
        else
          render_error(result[:error], status: :bad_gateway, code: "AI_FAILED")
        end
      rescue PDF::Reader::MalformedPDFError
        render_error("The uploaded PDF could not be read.", status: :unprocessable_entity, code: "INVALID_PDF")
      rescue StandardError => e
        Rails.logger.error "AI request failed for user #{current_user.id}: #{e.class}: #{e.message}"
        render_error("The configured AI provider is unavailable. Please try again shortly.", status: :bad_gateway, code: "AI_PROVIDER_UNAVAILABLE")
      end

      def progress
        render_success(role_progress)
      end

      def tutor_report
        schedules = current_user.taught_schedules.includes(:active_enrollments, :assignments)
        report = schedules.map do |schedule|
          {
            schedule_id: schedule.id,
            schedule_title: schedule.title,
            course_code: schedule.course_code,
            students: schedule.active_students.map { |student| student_tutor_summary(student) }
          }
        end
        render_success(report)
      end

      # ---- Conversational AI assistant ----

      # GET /api/v1/ai/chat — full conversation history (oldest first).
      def chat_history
        render_success({
          messages: AiChatMessage.conversation_for(current_user).map { |m| serialize_chat_message(m) }
        })
      end

      # POST /api/v1/ai/chat — send a message, get the assistant reply.
      def chat
        content = params[:message].to_s.strip
        return render_error("Please enter a message for the AI assistant.", status: :unprocessable_entity, code: "MESSAGE_REQUIRED") if content.blank?

        user_message = AiChatMessage.record!(current_user, role: "user", content: content)

        provider = AiServiceFactory.provider
        prompt = build_chat_prompt(content)

        result = provider.answer_prompt(prompt, user_id: current_user.id)

        if result[:success]
          assistant_message = AiChatMessage.record!(
            current_user,
            role: "assistant",
            content: result[:summary],
            status: "completed",
            tokens_used: result[:tokens_used]
          )
          render_success({
            message: serialize_chat_message(assistant_message),
            messages: AiChatMessage.conversation_for(current_user).map { |m| serialize_chat_message(m) }
          })
        elsif result[:rate_limited]
          user_message.update!(status: "rate_limited")
          render_error(result[:error], status: :too_many_requests, code: "RATE_LIMITED")
        else
          user_message.update!(status: "failed")
          render_error(result[:error], status: :bad_gateway, code: "AI_FAILED")
        end
      end

      # DELETE /api/v1/ai/chat — clears the conversation history.
      def chat_reset
        AiChatMessage.clear_for!(current_user)
        render_message("Conversation cleared")
      end

      private

      def require_teacher
        return if current_user.teacher? || current_user.tutor?
        render_forbidden
      end

      # Builds a prompt that embeds the role-aware user context plus recent
      # conversation history so the assistant has conversational memory.
      def build_chat_prompt(content)
        history = AiChatMessage.conversation_for(current_user).last(CHAT_HISTORY_LIMIT)
        history_lines = history.map do |m|
          speaker = m.role == "assistant" ? "Assistant" : "Student"
          "#{speaker}: #{m.content}"
        end.join("\n")

        <<~PROMPT
          You are UniHub AI, a helpful academic assistant for #{current_user.full_name}, who is a #{current_user.role}.

          Use this private context about the user when relevant (never invent data):
          #{user_context.to_json}

          Recent conversation (older → newer):
          #{history_lines.presence || "(no previous messages)"}

          Student request:
          #{content}

          Respond helpfully, concisely and specifically.
        PROMPT
      end

      # Role-aware context included in AI prompts.
      def user_context
        if current_user.admin?
          {
            role: current_user.role,
            full_name: current_user.full_name,
            departments: Department.count,
            students: User.where(role: 'student').count,
            staff: User.where(role: %w[teacher tutor]).count,
            schedules: Schedule.count,
            assignments: Assignment.count
          }
        elsif current_user.teacher? || current_user.tutor?
          {
            role: current_user.role,
            full_name: current_user.full_name,
            teaching_departments: current_user.teaching_departments.map(&:name),
            taught_schedules: current_user.taught_schedules.includes(:active_enrollments).map do |s|
              { title: s.title, course: s.course_code, day: s.day_name, time: s.formatted_time_range, room: s.room, students: s.active_enrollments.count }
            end,
            created_assignments: current_user.created_assignments.limit(10).map do |a|
              { title: a.title, course: a.course_name, due_date: a.due_date, points: a.points }
            end
          }
        else
          student_context
        end
      end

      def role_progress
        if current_user.admin?
          {
            status: "on_track",
            score: 100,
            label: "Platform overview",
            metrics: {
              upcoming_assignments: Assignment.where("due_date >= ?", Time.current).count,
              overdue_assignments: Assignment.where("due_date < ?", Time.current).count,
              pending_submissions: Submission.where(submitted_at: nil).count,
              average_grade: nil,
              recent_notes: Note.where("updated_at >= ?", 14.days.ago).count,
              scheduled_classes: Schedule.count,
              departments: Department.count,
              students: User.where(role: 'student').count,
              staff: User.where(role: %w[teacher tutor]).count
            },
            upcoming: []
          }
        elsif current_user.teacher? || current_user.tutor?
          assignments = current_user.created_assignments
          {
            status: "on_track",
            score: 100,
            label: "Teaching overview",
            metrics: {
              upcoming_assignments: assignments.where("due_date >= ?", Time.current).count,
              overdue_assignments: assignments.where("due_date < ?", Time.current).count,
              pending_submissions: Submission.where(assignment: assignments, submitted_at: nil).count,
              average_grade: nil,
              recent_notes: current_user.notes.where("updated_at >= ?", 14.days.ago).count,
              scheduled_classes: current_user.taught_schedules.count,
              students: assignments.joins(:submissions).count
            },
            upcoming: assignments.where("due_date >= ?", Time.current).order(due_date: :asc).limit(5).map do |a|
              { title: a.title, due_date: a.due_date, course: a.course_name }
            end
          }
        else
          student_progress
        end
      end

      def student_progress
        assignments = current_user.visible_assignments
        submissions = current_user.submissions.includes(:assignment)
        upcoming = assignments.where("due_date >= ?", Time.current).order(due_date: :asc).limit(5)
        overdue = assignments.where("due_date < ?", Time.current).where.not(id: submissions.select(:assignment_id))
        graded = submissions.where.not(grade: nil)
        average = graded.any? ? (graded.sum { |submission| submission.percentage_grade.to_f } / graded.size).round : nil
        submitted_ids = submissions.where.not(submitted_at: nil).pluck(:assignment_id)
        pending = assignments.where.not(id: submitted_ids).where("due_date >= ?", Time.current).count
        late = submissions.count(&:late_submission?)
        score = 100
        score -= 35 if overdue.exists?
        score -= 15 if pending >= 3
        score -= 15 if average && average < 60
        score -= 10 if late >= 2
        score += 10 if current_user.notes.where("updated_at >= ?", 14.days.ago).exists?
        score = [[score, 0].max, 100].min
        status = score < 45 ? "critical" : score < 75 ? "warning" : "on_track"

        {
          status: status,
          score: score,
          label: { "critical" => "Critical position", "warning" => "Needs attention", "on_track" => "On track" }.fetch(status),
          metrics: {
            upcoming_assignments: upcoming.count,
            overdue_assignments: overdue.count,
            pending_submissions: pending,
            average_grade: average,
            recent_notes: current_user.notes.where("updated_at >= ?", 14.days.ago).count,
            scheduled_classes: current_user.active_schedules.count
          },
          upcoming: upcoming.map { |assignment| { title: assignment.title, due_date: assignment.due_date, course: assignment.course_title } }
        }
      end

      def student_tutor_summary(student)
        assignments = student.visible_assignments
        submissions = student.submissions.includes(:assignment)
        graded = submissions.where.not(grade: nil)
        {
          student_id: student.id,
          student_name: student.full_name,
          assignments_count: assignments.count,
          submitted_count: submissions.where.not(submitted_at: nil).count,
          graded_count: graded.count,
          average_grade: graded.any? ? (graded.sum { |s| s.percentage_grade.to_f } / graded.size).round : nil,
          progress_score: student_progress_for(student)
        }
      end

      def student_progress_for(student)
        assignments = student.visible_assignments
        submissions = student.submissions
        overdue = assignments.where("due_date < ?", Time.current).where.not(id: submissions.select(:assignment_id))
        submitted_ids = submissions.where.not(submitted_at: nil).pluck(:assignment_id)
        pending = assignments.where.not(id: submitted_ids).where("due_date >= ?", Time.current).count
        score = 100
        score -= 35 if overdue.exists?
        score -= 15 if pending >= 3
        [[score, 0].max, 100].min
      end

      def with_student_context(text)
        return text if params[:file].present?

        <<~CONTEXT
          #{text}

          Use this private student context when it is relevant:
          #{student_context.to_json}
        CONTEXT
      end

      def build_document_prompt(prompt, document_text)
        return document_text if prompt.blank?

        <<~DOCUMENT
          Student request:
          #{prompt}

          Attached PDF content:
          #{document_text}

          Base your answer on the attached PDF and follow the student's request exactly.
        DOCUMENT
      end

      def student_context
        progress = student_progress
        {
          progress_status: progress[:status],
          progress_score: progress[:score],
          progress_metrics: progress[:metrics],
          upcoming_assignments: progress[:upcoming],
          schedule: current_user.active_schedules.order(:day_of_week, :start_time).limit(8).map do |schedule|
            { title: schedule.title, course: schedule.course_code, day: schedule.day_name, time: schedule.formatted_time_range, room: schedule.room }
          end,
          recent_notes: current_user.notes.recent.limit(8).map { |note| { title: note.title, content: note.plain_text_content.to_s.first(600) } },
          recent_insights: current_user.learning_insights.active.recent.limit(5).map { |insight| { title: insight.title, priority: insight.priority, description: insight.description } }
        }
      end

      def serialize_chat_message(message)
        {
          id: message.id,
          role: message.role,
          content: message.content,
          status: message.status,
          tokens_used: message.tokens_used,
          created_at: message.created_at
        }
      end
    end
  end
end