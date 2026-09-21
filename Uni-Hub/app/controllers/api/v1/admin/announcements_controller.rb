module Api
  module V1
    module Admin
      class AnnouncementsController < BaseController
        before_action :set_announcement, only: [:show, :update, :destroy, :publish, :unpublish]

        def index
          announcements = Announcement.all
          announcements = announcements.where(department_id: params[:department_id]) if params[:department_id].present?
          render_success(announcements.includes(:user, :department).order(created_at: :desc).map { |a| serialize_announcement(a) })
        end

        def show
          render_success(serialize_announcement(@announcement))
        end

        def create
          announcement = Announcement.new(announcement_params.merge(user: current_user))
          announcement.department_id ||= current_user&.department_id
          announcement.department_id ||= Department.first&.id

          if announcement.save
            announcement.publish! unless ActiveModel::Type::Boolean.new.cast(request_published_param) == false
            NotificationService.notify_announcement_published(announcement) if announcement.published?
            render_success(serialize_announcement(announcement), status: :created)
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: announcement.errors.messages
            )
          end
        end

        def update
          if @announcement.update(announcement_params)
            render_success(serialize_announcement(@announcement))
          else
            render_error(
              "Validation failed",
              status: :unprocessable_entity,
              code: "VALIDATION_ERROR",
              errors: @announcement.errors.messages
            )
          end
        end

        def destroy
          @announcement.destroy
          render_message("Announcement deleted successfully")
        end

        def publish
          @announcement.publish! unless @announcement.published?
          NotificationService.notify_announcement_published(@announcement)
          render_success(serialize_announcement(@announcement))
        end

        def unpublish
          @announcement.unpublish!
          render_success(serialize_announcement(@announcement))
        end

        private

        def set_announcement
          @announcement = Announcement.find(params[:id])
        end

        # `published` is an API flag, not a model column (the model uses `published_at`),
        # so it must be consumed separately and never mass-assigned.
        def request_published_param
          params.dig(:announcement, :published)
        end

        def announcement_params
          params.expect(announcement: {}).permit(
            :title, :content, :priority, :department_id, :pinned, :expires_at
          )
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
            author_id: announcement.user_id,
            author_name: announcement.user&.full_name,
            published: announcement.published?,
            published_at: announcement.published_at,
            expires_at: announcement.expires_at,
            created_at: announcement.created_at,
            updated_at: announcement.updated_at
          }
        end
      end
    end
  end
end