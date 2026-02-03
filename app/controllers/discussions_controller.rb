class DiscussionsController < ApplicationController
  layout 'dashboard'
  before_action :authenticate_user!
  before_action :set_discussion, only: [:show, :edit, :update, :destroy, :close, :reopen, :pin, :unpin, :archive]
  before_action :check_discussion_access, only: [:edit, :update, :destroy, :close, :reopen, :pin, :unpin, :archive]
  
  def index
    @discussions = Discussion.includes(:user, :discussion_posts)
                            .active
                            .by_category(params[:category])
                            .page(params[:page] || 1)
                            .per(20)
    
    # Handle sorting
    case params[:sort]
    when 'popular'
      @discussions = @discussions.popular
    when 'oldest'
      @discussions = @discussions.order(:created_at)
    else
      @discussions = @discussions.with_activity
    end
    
    @categories = Discussion.categories
    @selected_category = params[:category]
    @discussion_stats = {
      total: Discussion.count,
      open: Discussion.open.count,
      pinned: Discussion.pinned.count,
      my_discussions: current_user.discussions.count
    }
  end

  def show
    @discussion.increment_views!
    
    @posts = @discussion.discussion_posts
                       .includes(:user, :replies)
                       .top_level
                       .oldest_first
                       .page(params[:page] || 1)
                       .per(10)
    
    # Load replies for each post
    @replies = {}
    @posts.each do |post|
      @replies[post.id] = post.replies.includes(:user).oldest_first.limit(20)
    end
    
    @new_post = @discussion.discussion_posts.build
    @reply_post = DiscussionPost.new
  end

  def new
    @discussion = current_user.discussions.build
    @categories = Discussion.categories
  end

  def create
    @discussion = current_user.discussions.build(discussion_params)
    
    if @discussion.save
      redirect_to @discussion, notice: 'Discussion was successfully created.'
    else
      @categories = Discussion.categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Discussion.categories
  end

  def update
    if @discussion.update(discussion_params)
      redirect_to @discussion, notice: 'Discussion was successfully updated.'
    else
      @categories = Discussion.categories
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discussion.destroy
    redirect_to discussions_path, notice: 'Discussion was successfully deleted.'
  end
  
  # Discussion status management
  def close
    @discussion.close!
    redirect_back(fallback_location: @discussion, notice: 'Discussion closed.')
  end
  
  def reopen
    @discussion.reopen!
    redirect_back(fallback_location: @discussion, notice: 'Discussion reopened.')
  end
  
  def pin
    @discussion.pin!
    redirect_back(fallback_location: @discussion, notice: 'Discussion pinned.')
  end
  
  def unpin
    @discussion.unpin!
    redirect_back(fallback_location: @discussion, notice: 'Discussion unpinned.')
  end
  
  def archive
    @discussion.archive!
    redirect_back(fallback_location: discussions_path, notice: 'Discussion archived.')
  end
  
  # AJAX endpoints
  def create_post
    @discussion = Discussion.find(params[:discussion_id])
    @post = @discussion.discussion_posts.build(post_params)
    @post.user = current_user
    
    respond_to do |format|
      if @post.save
        format.json { 
          render json: { 
            success: true, 
            post_html: render_to_string(partial: 'discussions/post', locals: { post: @post, discussion: @discussion }),
            posts_count: @discussion.posts_count
          } 
        }
        format.html { redirect_to @discussion }
      else
        format.json { render json: { success: false, errors: @post.errors.full_messages } }
        format.html { 
          @posts = @discussion.discussion_posts.includes(:user, :replies).top_level.oldest_first
          render 'discussions/show', status: :unprocessable_entity 
        }
      end
    end
  end
  
  def create_reply
    @parent_post = DiscussionPost.find(params[:parent_id])
    @discussion = @parent_post.discussion
    @reply = @parent_post.replies.build(post_params)
    @reply.discussion = @discussion
    @reply.user = current_user
    
    respond_to do |format|
      if @reply.save
        format.json { 
          render json: { 
            success: true, 
            reply_html: render_to_string(partial: 'discussions/reply', locals: { reply: @reply }),
            replies_count: @parent_post.replies_count
          } 
        }
        format.html { redirect_to @discussion }
      else
        format.json { render json: { success: false, errors: @reply.errors.full_messages } }
        format.html { redirect_to @discussion }
      end
    end
  end
  
  def search
    query = params[:q].to_s.strip
    
    if query.present?
      @discussions = Discussion.includes(:user)
                              .where("title ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%")
                              .active
                              .by_category(params[:category])
                              .with_activity
                              .limit(20)
    else
      @discussions = []
    end
    
    render json: @discussions.map { |discussion|
      {
        id: discussion.id,
        title: discussion.title,
        description: truncate(discussion.description, length: 100),
        category: discussion.category,
        author: discussion.user.name,
        posts_count: discussion.posts_count,
        created_at: discussion.created_at,
        url: discussion_path(discussion)
      }
    }
  end

  private

  def set_discussion
    @discussion = Discussion.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to discussions_path, alert: 'Discussion not found'
  end
  
  def check_discussion_access
    unless @discussion.user == current_user || current_user.teacher? || current_user.admin?
      redirect_to @discussion, alert: 'You do not have permission to perform this action'
    end
  end

  def discussion_params
    params.require(:discussion).permit(:title, :description, :category, :status)
  end
  
  def post_params
    params.require(:discussion_post).permit(:content)
  end
end
