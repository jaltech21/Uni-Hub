module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_success(empty_results) if query.blank?

        results = {
          notes: note_results(query),
          assignments: assignment_results(query),
          users: user_results(query),
          announcements: announcement_results(query)
        }
        render_success(results)
      end

      private

      def note_results(query)
        if current_user.admin? || current_user.teacher?
          current_user.all_departments.flat_map { |d| d.notes.search(query) }.uniq
        else
          current_user.notes.search(query)
        end
      end

      def assignment_results(query)
        if current_user.teacher?
          current_user.created_assignments.where("title ILIKE ?", "%#{query}%")
        else
          current_user.visible_assignments.where("title ILIKE ?", "%#{query}%")
        end
      end

      def user_results(query)
        User.where.not(id: current_user.id)
            .where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%")
            .limit(10)
      end

      def announcement_results(query)
        Announcement.published.where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%").limit(10)
      end

      def empty_results
        { notes: [], assignments: [], users: [], announcements: [] }
      end
    end
  end
end