class ContentTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: [:show, :edit, :update, :destroy, :duplicate, :favorite, :unfavorite, :review, :use_template]
  before_action :check_edit_permissions, only: [:edit, :update, :destroy]
  
  # GET /content_templates
  def index
    @templates = ContentTemplate.published
                               .accessible_templates(current_user)
                               .includes(:created_by, :department, :template_reviews, :template_favorites)
    
    # Apply filters
    @templates = apply_filters(@templates)
    
    # Pagination
    @templates = @templates.page(params[:page]).per(12)
    
    # Categories and tags for filters
    @categories = ContentTemplate.published.distinct.pluck(:category).compact.sort
    @template_types = %w[assignment note quiz]
    @departments = current_user.accessible_departments
    
    respond_to do |format|
      format.html
      format.json { render json: templates_json(@templates) }
    end
  end
  
  # GET /content_templates/marketplace
  def marketplace
    @featured_templates = ContentTemplate.published
                                        .featured
                                        .accessible_templates(current_user)
                                        .includes(:created_by, :template_reviews)
                                        .limit(6)
    
    @popular_templates = TemplateUsage.popular_templates(8)
                                    .select { |t| t.accessible_to?(current_user) }
    
    @trending_templates = TemplateUsage.trending_templates(7, 8)
                                     .select { |t| t.accessible_to?(current_user) }
    
    @recent_templates = ContentTemplate.published
                                      .accessible_templates(current_user)
                                      .recent
                                      .includes(:created_by, :template_reviews)
                                      .limit(8)
    
    @categories = ContentTemplate.published.distinct.pluck(:category).compact.sort
    @my_favorites = current_user.template_favorites
                               .includes(:content_template)
                               .recent
                               .limit(4)
                               .map(&:content_template)
  end
  
  # GET /content_templates/1
  def show
    unless @template.accessible_to?(current_user)
      redirect_to content_templates_path, alert: 'Template not found or not accessible.'
      return
    end
    
    @reviews = @template.template_reviews
                       .includes(:user)
                       .recent
                       .limit(10)
    
    @related_templates = ContentTemplate.published
                                       .where(template_type: @template.template_type)
                                       .where.not(id: @template.id)
                                       .accessible_templates(current_user)
                                       .limit(4)
    
    @usage_stats = TemplateUsage.usage_stats_for_template(@template)
    @is_favorited = @template.favorited_by?(current_user)
    @user_review = @template.template_reviews.find_by(user: current_user)
    
    respond_to do |format|
      format.html
      format.json { render json: template_detail_json(@template) }
    end
  end
  
  # GET /content_templates/new
  def new
    @template = ContentTemplate.new
    @template.template_type = params[:type] if params[:type].present?
    @template.department = current_user.department
    
    @categories = ContentTemplate.distinct.pluck(:category).compact.sort
    @parent_template = ContentTemplate.find(params[:parent_id]) if params[:parent_id]
    
    if @parent_template
      @template = @parent_template.duplicate(current_user)
      @template.name = "Copy of #{@parent_template.name}"
    end
  end
  
  # POST /content_templates
  def create
    @template = ContentTemplate.new(template_params)
    @template.created_by = current_user
    @template.department = current_user.department unless template_params[:visibility] == 'public'
    
    if @template.save
      redirect_to @template, notice: 'Template created successfully.'
    else
      @categories = ContentTemplate.distinct.pluck(:category).compact.sort
      render :new, status: :unprocessable_entity
    end
  end
  
  # GET /content_templates/1/edit
  def edit
    @categories = ContentTemplate.distinct.pluck(:category).compact.sort
  end
  
  # PATCH/PUT /content_templates/1
  def update
    if @template.update(template_params)
      @template.bump_version!(:patch) if template_params[:content] != @template.content_was
      redirect_to @template, notice: 'Template updated successfully.'
    else
      @categories = ContentTemplate.distinct.pluck(:category).compact.sort
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /content_templates/1
  def destroy
    @template.update(status: 'archived')
    redirect_to content_templates_path, notice: 'Template archived successfully.'
  end
  
  # POST /content_templates/1/duplicate
  def duplicate
    unless @template.accessible_to?(current_user)
      redirect_to content_templates_path, alert: 'Template not accessible.'
      return
    end
    
    new_template = @template.duplicate(current_user, params[:name])
    
    if new_template
      redirect_to edit_content_template_path(new_template), notice: 'Template duplicated successfully.'
    else
      redirect_to @template, alert: 'Failed to duplicate template.'
    end
  end
  
  # POST /content_templates/1/favorite
  def favorite
    unless @template.accessible_to?(current_user)
      render json: { error: 'Template not accessible' }, status: :forbidden
      return
    end
    
    favorite = @template.template_favorites.build(user: current_user)
    
    if favorite.save
      render json: { 
        favorited: true, 
        favorites_count: @template.total_favorites,
        message: 'Template added to favorites'
      }
    else
      render json: { error: 'Failed to favorite template' }, status: :unprocessable_entity
    end
  end
  
  # DELETE /content_templates/1/unfavorite
  def unfavorite
    favorite = @template.template_favorites.find_by(user: current_user)
    
    if favorite&.destroy
      render json: { 
        favorited: false, 
        favorites_count: @template.total_favorites,
        message: 'Template removed from favorites'
      }
    else
      render json: { error: 'Failed to unfavorite template' }, status: :unprocessable_entity
    end
  end
  
  # POST /content_templates/1/review
  def review
    unless @template.accessible_to?(current_user)
      render json: { error: 'Template not accessible' }, status: :forbidden
      return
    end
    
    @review = @template.template_reviews.find_or_initialize_by(user: current_user)
    @review.assign_attributes(review_params)
    
    if @review.save
      render json: {
        success: true,
        review: review_json(@review),
        average_rating: @template.average_rating,
        message: 'Review saved successfully'
      }
    else
      render json: { 
        error: 'Failed to save review',
        errors: @review.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  # POST /content_templates/1/use
  def use_template
    unless @template.accessible_to?(current_user)
      render json: { error: 'Template not accessible' }, status: :forbidden
      return
    end
    
    content = @template.create_content(current_user, content_creation_params)
    
    if content&.persisted?
      # Track usage
      TemplateUsage.create!(
        content_template: @template,
        user: current_user,
        used_at: Time.current,
        context: "#{@template.template_type}_creation"
      )
      
      @template.increment_usage!
      
      render json: {
        success: true,
        content_id: content.id,
        content_type: content.class.name.downcase,
        redirect_url: polymorphic_path(content),
        message: "#{content.class.name} created from template successfully"
      }
    else
      render json: { 
        error: 'Failed to create content from template',
        errors: content&.errors&.full_messages || ['Unknown error']
      }, status: :unprocessable_entity
    end
  end
  
  # GET /content_templates/search
  def search
    query = params[:q]
    filters = search_params
    
    @templates = ContentTemplate.published
                               .accessible_templates(current_user)
                               .search(query)
    
    @templates = apply_search_filters(@templates, filters)
    @templates = @templates.includes(:created_by, :department, :template_reviews)
                          .page(params[:page])
                          .per(12)
    
    respond_to do |format|
      format.html { render :index }
      format.json { render json: templates_json(@templates) }
    end
  end
  
  # GET /content_templates/my_templates
  def my_templates
    @templates = current_user.content_templates
                           .includes(:template_reviews, :template_favorites, :template_usages)
                           .order(updated_at: :desc)
                           .page(params[:page])
                           .per(12)
    
    @draft_count = current_user.content_templates.where(status: 'draft').count
    @published_count = current_user.content_templates.where(status: 'published').count
    @total_usage = TemplateUsage.joins(:content_template)
                               .where(content_templates: { created_by: current_user })
                               .count
  end
  
  # GET /content_templates/favorites
  def favorites
    @favorite_templates = current_user.template_favorites
                                    .includes(content_template: [:created_by, :template_reviews])
                                    .recent
                                    .page(params[:page])
                                    .per(12)
                                    .map(&:content_template)
  end
  
  private
  
  def set_template
    @template = ContentTemplate.find(params[:id])
  end
  
  def check_edit_permissions
    unless @template.editable_by?(current_user)
      redirect_to @template, alert: 'You do not have permission to edit this template.'
    end
  end
  
  def template_params
    params.require(:content_template).permit(
      :name, :description, :template_type, :content, :category, :tags,
      :visibility, :status, tag_list: [], metadata: {}
    )
  end
  
  def review_params
    params.require(:template_review).permit(:rating, :review_text)
  end
  
  def search_params
    params.permit(:type, :category, :department_id, :sort, tags: [])
  end
  
  def content_creation_params
    params.permit(:title, :due_date, :time_limit, :attempts_allowed)
  end
  
  def apply_filters(templates)
    templates = templates.by_type(params[:type]) if params[:type].present?
    templates = templates.by_category(params[:category]) if params[:category].present?
    templates = templates.where(department_id: params[:department_id]) if params[:department_id].present?
    templates = templates.with_tags(params[:tags]) if params[:tags].present?
    templates = templates.featured if params[:featured] == 'true'
    
    case params[:sort]
    when 'popular'
      templates.joins(:template_usages).group('content_templates.id').order('COUNT(template_usages.id) DESC')
    when 'rating'
      templates.joins(:template_reviews).group('content_templates.id').order('AVG(template_reviews.rating) DESC')
    when 'name'
      templates.order(:name)
    when 'recent'
      templates.recent
    else
      templates.recent
    end
  end
  
  def apply_search_filters(templates, filters)
    templates = templates.by_type(filters[:type]) if filters[:type].present?
    templates = templates.by_category(filters[:category]) if filters[:category].present?
    templates = templates.where(department_id: filters[:department_id]) if filters[:department_id].present?
    templates = templates.with_tags(filters[:tags]) if filters[:tags].present?
    
    case filters[:sort]
    when 'relevance'
      templates # Already ordered by search relevance
    when 'popular'
      templates.popular
    when 'recent'
      templates.recent
    else
      templates
    end
  end
  
  def templates_json(templates)
    {
      templates: templates.map { |t| t.preview_data },
      pagination: {
        current_page: templates.current_page,
        total_pages: templates.total_pages,
        total_count: templates.total_count
      }
    }
  end
  
  def template_detail_json(template)
    template.preview_data.merge(
      content: template.content,
      metadata: template.metadata,
      reviews: @reviews.map { |r| review_json(r) },
      usage_stats: @usage_stats,
      is_favorited: @is_favorited,
      user_review: @user_review ? review_json(@user_review) : nil
    )
  end
  
  def review_json(review)
    {
      id: review.id,
      rating: review.rating,
      review_text: review.review_text,
      helpful_votes: review.helpful_votes,
      user_name: review.user.name,
      created_at: review.created_at
    }
  end
end

# Add scope to ContentTemplate model for accessibility
class ContentTemplate < ApplicationRecord
  scope :accessible_templates, ->(user) {
    where(
      "(visibility = 'public') OR " \
      "(visibility = 'private' AND created_by_id = ?) OR " \
      "(visibility = 'department' AND department_id = ?) OR " \
      "(visibility = 'institutional')",
      user.id, user.department_id
    )
  }
end