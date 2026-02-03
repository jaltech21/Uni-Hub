class VersionHistoryController < ApplicationController
  before_action :authenticate_user!
  before_action :set_versionable
  before_action :check_permissions
  before_action :set_version, only: [:show, :restore, :compare, :download]
  
  # GET /assignments/1/versions
  # GET /notes/1/versions
  # GET /quizzes/1/versions
  def index
    @versions = @versionable.version_history(limit: params[:limit] || 20)
    @current_version = @versionable.published_version
    @draft_version = @versionable.current_draft
    
    respond_to do |format|
      format.html
      format.json { render json: { versions: @versions, current: @current_version&.id, draft: @draft_version&.id } }
    end
  end
  
  # GET /assignments/1/versions/123
  def show
    @version_details = {
      basic_info: @version.full_version_info,
      content_data: @version.content_data,
      statistics: @version.content_statistics,
      metadata: @version.metadata
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @version_details }
    end
  end
  
  # POST /assignments/1/versions/123/restore
  def restore
    begin
      restored_version = @versionable.restore_to_version!(@version.id)
      
      flash[:success] = "Successfully restored to version #{@version.version_tag}"
      
      respond_to do |format|
        format.html { redirect_to @versionable }
        format.json { render json: { success: true, version: restored_version.version_tag } }
      end
    rescue => e
      flash[:error] = "Failed to restore version: #{e.message}"
      
      respond_to do |format|
        format.html { redirect_to version_history_path }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end
  
  # GET /assignments/1/versions/compare?v1=123&v2=124
  def compare
    v1_id = params[:v1] || params[:version1_id]
    v2_id = params[:v2] || params[:version2_id] || @version.id
    
    if v1_id.blank? || v2_id.blank?
      flash[:error] = 'Please select two versions to compare'
      redirect_to version_history_path and return
    end
    
    begin
      @comparison = @versionable.compare_versions(v1_id, v2_id)
      @version1 = @versionable.content_versions.find(v1_id)
      @version2 = @versionable.content_versions.find(v2_id)
      
      respond_to do |format|
        format.html
        format.json { render json: @comparison }
      end
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'One or both versions not found'
      redirect_to version_history_path
    rescue => e
      flash[:error] = "Error comparing versions: #{e.message}"
      redirect_to version_history_path
    end
  end
  
  # GET /assignments/1/versions/123/download
  def download
    case params[:format]&.downcase
    when 'json'
      send_data @version.content_data.to_json, 
                filename: "#{@versionable.class.name.downcase}_#{@versionable.id}_v#{@version.version_tag}.json",
                type: 'application/json'
    when 'txt'
      content = extract_text_content(@version)
      send_data content,
                filename: "#{@versionable.class.name.downcase}_#{@versionable.id}_v#{@version.version_tag}.txt",
                type: 'text/plain'
    else
      flash[:error] = 'Unsupported download format'
      redirect_to version_history_path
    end
  end
  
  # POST /assignments/1/versions/create_branch
  def create_branch
    branch_name = params[:branch_name]
    from_version_id = params[:from_version_id]
    
    if branch_name.blank?
      flash[:error] = 'Branch name is required'
      redirect_to version_history_path and return
    end
    
    begin
      from_version = from_version_id.present? ? @versionable.content_versions.find(from_version_id) : nil
      branch_version = @versionable.versioning_service.create_branch(branch_name, from_version: from_version)
      
      flash[:success] = "Created branch '#{branch_name}'"
      
      respond_to do |format|
        format.html { redirect_to version_history_path }
        format.json { render json: { success: true, branch_version: branch_version.version_tag } }
      end
    rescue => e
      flash[:error] = "Failed to create branch: #{e.message}"
      
      respond_to do |format|
        format.html { redirect_to version_history_path }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end
  
  # POST /assignments/1/versions/publish_draft
  def publish_draft
    if @versionable.current_draft.nil?
      flash[:error] = 'No draft version to publish'
      redirect_to version_history_path and return
    end
    
    begin
      if @versionable.publish_draft!
        flash[:success] = 'Draft version published successfully'
      else
        flash[:error] = 'Failed to publish draft version'
      end
      
      respond_to do |format|
        format.html { redirect_to @versionable }
        format.json { render json: { success: true } }
      end
    rescue => e
      flash[:error] = "Error publishing draft: #{e.message}"
      
      respond_to do |format|
        format.html { redirect_to version_history_path }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end
  
  # GET /assignments/1/versions/changes_summary
  def changes_summary
    since_date = params[:since]&.to_date || 1.week.ago
    @summary = @versionable.versioning_service.changes_summary(since: since_date)
    
    respond_to do |format|
      format.html { render partial: 'changes_summary' }
      format.json { render json: @summary }
    end
  end
  
  # DELETE /assignments/1/versions/123
  def destroy
    if @version.can_destroy?
      @version.destroy
      flash[:success] = "Version #{@version.version_tag} deleted"
    else
      flash[:error] = "Cannot delete this version"
    end
    
    respond_to do |format|
      format.html { redirect_to version_history_path }
      format.json { render json: { success: @version.destroyed? } }
    end
  end
  
  private
  
  def set_versionable
    # Determine the parent resource from the URL
    if params[:assignment_id]
      @versionable = Assignment.find(params[:assignment_id])
      @resource_name = 'assignment'
    elsif params[:note_id]
      @versionable = Note.find(params[:note_id])
      @resource_name = 'note'
    elsif params[:quiz_id]
      @versionable = Quiz.find(params[:quiz_id])
      @resource_name = 'quiz'
    else
      raise ActionController::ParameterMissing, 'No parent resource specified'
    end
  end
  
  def set_version
    @version = @versionable.content_versions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'Version not found'
    redirect_to version_history_path
  end
  
  def check_permissions
    # Check if user can view version history
    case @versionable
    when Assignment
      unless @versionable.user == current_user || current_user.admin?
        flash[:error] = 'You do not have permission to view this version history'
        redirect_to root_path and return
      end
    when Note
      unless @versionable.viewable_by?(current_user)
        flash[:error] = 'You do not have permission to view this version history'
        redirect_to root_path and return
      end
    when Quiz
      unless @versionable.user == current_user || current_user.admin?
        flash[:error] = 'You do not have permission to view this version history'
        redirect_to root_path and return
      end
    end
  end
  
  def version_history_path
    case @resource_name
    when 'assignment'
      assignment_versions_path(@versionable)
    when 'note'
      note_versions_path(@versionable)
    when 'quiz'
      quiz_versions_path(@versionable)
    end
  end
  
  def extract_text_content(version)
    content_data = version.content_data
    text_parts = []
    
    # Extract main text fields
    %w[title description content body instructions].each do |field|
      if content_data[field].present?
        text_parts << "#{field.humanize}:\n#{content_data[field]}\n"
      end
    end
    
    # Add metadata
    text_parts << "\nVersion: #{version.version_tag}"
    text_parts << "Author: #{version.user.name}"
    text_parts << "Created: #{version.created_at}"
    text_parts << "Summary: #{version.change_summary}"
    
    text_parts.join("\n")
  end
end