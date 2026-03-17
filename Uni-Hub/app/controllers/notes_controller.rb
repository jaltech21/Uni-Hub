class NotesController < ApplicationController
  layout 'dashboard'
  before_action :set_note, only: %i[show edit update destroy share export auto_save]
  before_action :check_edit_permission, only: [:edit, :update, :destroy]
  before_action :authenticate_user!

  def index
    @folders = current_user.folders.ordered
    @all_tags = Tag.joins(:notes).where(notes: { user_id: current_user.id }).distinct.alphabetical
    
    # Get department context: only filter if explicitly selected
    @filter_department = if params[:department_id].present?
      Department.find_by(id: params[:department_id])
    end
    
    # Use Pundit scope to get authorized notes
    base_notes = policy_scope(Note)
    
    # Apply filters
    if params[:folder_id].present?
      base_notes = base_notes.in_folder(params[:folder_id])
    elsif params[:folder_id] == 'none'
      base_notes = base_notes.without_folder
    elsif params[:tag].present?
      base_notes = base_notes.tagged_with(params[:tag])
    end
    
    # Apply department filter only if explicitly selected
    base_notes = base_notes.by_department(@filter_department) if @filter_department
    
    # Set current context
    @current_folder = current_user.folders.find(params[:folder_id]) if params[:folder_id].present?
    @current_tag = params[:tag] if params[:tag].present?
    
    # Search
    @notes = params[:q].present? ? base_notes.search(params[:q]) : base_notes
    
    @notes = @notes.includes(:folder, :tags, :user).recent
    @shared_notes = policy_scope(Note).where.not(user: current_user).includes(:user, :folder).recent.limit(10)
  end

  def show
    authorize @note
  end

  def new
    @note = Note.new
    @note.folder_id = params[:folder_id] if params[:folder_id].present?
    @folders = current_user.folders.ordered
    authorize @note
  end

  def create
    @note = current_user.notes.build(note_params)
    @note.department_id ||= current_department&.id
    authorize @note
    
    # Handle tags
    if params[:note][:tag_list].present?
      @note.tag_list = params[:note][:tag_list]
    end
    
    if @note.save
      redirect_to @note, notice: 'Note was successfully created.'
    else
      @folders = current_user.folders.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @folders = current_user.folders.ordered
    authorize @note
  end

  def update
    authorize @note
    
    # Handle tags
    if params[:note][:tag_list].present?
      @note.tag_list = params[:note][:tag_list]
    end
    
    if @note.update(note_params)
      redirect_to @note, notice: 'Note was successfully updated.'
    else
      @folders = current_user.folders.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @note
    @note.destroy
    redirect_to notes_url, notice: 'Note was successfully destroyed.'
  end
  
  # POST /notes/:id/share
  def share
    authorize @note
    
    user_email = params[:user_email]
    permission = params[:permission] || 'view'
    
    shared_user = User.find_by(email: user_email)
    
    if shared_user.nil?
      redirect_to @note, alert: 'User not found with that email address.' and return
    end
    
    if @note.share_with(shared_user, permission: permission)
      # Notify user that note was shared with them
      Notification.notify_note_shared(shared_user, @note, current_user)
      
      redirect_to @note, notice: "Note shared with #{shared_user.full_name}."
    else
      redirect_to @note, alert: 'Failed to share note. User may already have access.'
    end
  rescue StandardError => e
    redirect_to @note, alert: "Error sharing note: #{e.message}"
  end
  
  # GET /notes/:id/export
  def export
    authorize @note
    
    respond_to do |format|
      format.md do
        send_data @note.to_markdown, 
          filename: "#{@note.title.parameterize}.md",
          type: 'text/markdown',
          disposition: 'attachment'
      end
    end
  end
  
  # POST /notes/:id/auto_save
  def auto_save
    authorize @note, :auto_save?
    
    if @note.update(note_params)
      render json: { success: true, updated_at: @note.updated_at }
    else
      render json: { success: false, errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_note
    @note = Note.find(params[:id])
  end
  
  def check_edit_permission
    authorize @note, :update?
  end

  def note_params
    params.require(:note).permit(:title, :content, :folder_id, :department_id)
  end
end