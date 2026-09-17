module Api
  module V1
    class AnnouncementsController < BaseController
      before_action :set_announcement, only: [:show]

      def index
        announcements = announcements_for_user.includes(:user, :department).published.recent
        paginated = paginate(announcements)
        render_success(
          paginated.map { |a| serialize_announcement(a) },
          meta: pagination_meta(paginated)
        )
      end

      def show
        return render_forbidden unless @announcement.published? || can_manage_announcements?
        render_success(serialize_announcement(@announcement))
      end

      private

      def set_announcement
        @announcement = Announcement.find(params[:id])
      end

      def announcements_for_user
        if current_user.admin?
          Announcement.all
        elsif current_user.teacher?
          Announcement.where(department_id: current_user.all_departments.pluck(:id))
        else
          Announcement.where(department_id: current_user.department_id)
        end
      end

      def can_manage_announcements?
        current_user.teacher? || current_user.admin?
      end

      def serialize_announcement(announcement)
        {
          id: announcement.id,
          title: announcement.title,
          content: announcement.content,
          priority: announcement.priority,
          pinned: announcement.pinned,
          department_id: announcement.department_id,
          department_name: announcement.department&.name,
          author_name: announcement.user&.full_name,
          published_at: announcement.published_at,
          expires_at: announcement.expires_at,
          created_at: announcement.created_at,
          updated_at: announcement.updated_at
        }
      end
    end
  end
end