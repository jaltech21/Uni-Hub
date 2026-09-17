module Api
  module V1
    class HomeController < BaseController
      def stats
        render_success({
          classes_today: schedule_scope.for_day(Time.current.wday).count,
          assignments_due: assignment_scope.upcoming.count,
          notes_count: current_user.notes.count,
          today_schedule: schedule_scope.for_day(Time.current.wday).by_start_time.map { |s| serialize_schedule(s) },
          upcoming_tasks: assignment_scope.upcoming.limit(5).map { |a| serialize_assignment(a) }
        })
      end

      private

      def schedule_scope
        if current_user.admin?
          Schedule.all
        elsif current_user.teacher?
          Schedule.where(instructor_id: current_user.id)
        else
          current_user.enrolled_schedules
        end
      end

      def assignment_scope
        if current_user.teacher?
          current_user.created_assignments
        else
          current_user.visible_assignments
        end
      end

      def serialize_schedule(schedule)
        {
          id: schedule.id,
          title: schedule.title,
          start_time: schedule.start_time,
          end_time: schedule.end_time,
          day_of_week: schedule.day_of_week,
          day_name: schedule.day_name,
          location: schedule.room,
          course_name: schedule.course,
          course_id: schedule.id,
          student_id: current_user.id,
          status: schedule.status
        }
      end

      def serialize_assignment(assignment)
        {
          id: assignment.id,
          title: assignment.title,
          description: assignment.description,
          due_date: assignment.due_date,
          teacher_id: assignment.user_id,
          course_id: assignment.schedule_id,
          course_name: assignment.schedule&.course || assignment.course_name,
          created_at: assignment.created_at,
          updated_at: assignment.updated_at
        }
      end
    end
  end
end