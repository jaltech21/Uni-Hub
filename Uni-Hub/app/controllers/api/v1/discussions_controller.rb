module Api
  module V1
    class DiscussionsController < BaseController
      before_action :set_discussion, only: [:show]

      def index
        discussions = Discussion.includes(:user).active.recent
        discussions = discussions.by_category(params[:category]) if params[:category].present?
        paginated = paginate(discussions)
        render_success(
          paginated.map { |d| serialize_discussion(d) },
          meta: pagination_meta(paginated)
        )
      end

      def show
        render_success(serialize_discussion(@discussion, with_posts: true))
      end

      private

      def set_discussion
        @discussion = Discussion.find(params[:id])
      end

      def serialize_discussion(discussion, with_posts: false)
        payload = {
          id: discussion.id,
          title: discussion.title,
          description: discussion.description,
          category: discussion.category,
          status: discussion.status,
          author_id: discussion.user_id,
          author_name: discussion.user&.full_name,
          posts_count: discussion.posts_count,
          replies_count: discussion.replies_count,
          views_count: discussion.views_count,
          created_at: discussion.created_at,
          updated_at: discussion.updated_at
        }
        if with_posts
          payload[:posts] = discussion.discussion_posts.includes(:user).order(:created_at).map do |post|
            {
              id: post.id,
              content: post.content,
              author_id: post.user_id,
              author_name: post.user&.full_name,
              parent_id: post.parent_id,
              created_at: post.created_at
            }
          end
        end
        payload
      end
    end
  end
end