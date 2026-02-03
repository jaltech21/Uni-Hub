class AnnouncementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_announcement, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :toggle_pin]
  before_action :set_department, only: [:index, :new, :create]
  
  def index
    @announcements = policy_scope(Announcement)
                      .where(department: @department)
                      .includes(:user, :department)
                      .recent
    
    # Separate pinned and regular announcements
    @pinned_announcements = @announcements.pinned.active
    @regular_announcements = @announcements.where(pinned: false).active
    @draft_announcements = @announcements.draft if can_manage_announcements?
    @expired_announcements = @announcements.expired if can_manage_announcements?
  end
  
  def show
    authorize @announcement
  end
  
  def new
    @announcement = Announcement.new(department: @department)
    authorize @announcement
  end
  
  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.user = current_user
    @announcement.department = @department
    
    authorize @announcement
    
    if @announcement.save
      redirect_to announcements_path(department_id: @department.id), notice: 'Announcement was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    authorize @announcement
  end
  
  def update
    authorize @announcement
    
    if @announcement.update(announcement_params)
      redirect_to announcement_path(@announcement), notice: 'Announcement was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize @announcement
    department_id = @announcement.department_id
    @announcement.destroy
    
    redirect_to announcements_path(department_id: department_id), notice: 'Announcement was successfully deleted.'
  end
  
  def publish
    authorize @announcement, :publish?
    
    if @announcement.publish!
      redirect_to announcement_path(@announcement), notice: 'Announcement was successfully published.'
    else
      redirect_to announcement_path(@announcement), alert: 'Failed to publish announcement.'
    end
  end
  
  def unpublish
    authorize @announcement, :unpublish?
    
    if @announcement.unpublish!
      redirect_to announcement_path(@announcement), notice: 'Announcement was unpublished.'
    else
      redirect_to announcement_path(@announcement), alert: 'Failed to unpublish announcement.'
    end
  end
  
  def toggle_pin
    authorize @announcement, :toggle_pin?
    
    if @announcement.toggle_pin!
      status = @announcement.pinned? ? 'pinned' : 'unpinned'
      redirect_to announcements_path(department_id: @announcement.department_id), notice: "Announcement was #{status}."
    else
      redirect_to announcements_path(department_id: @announcement.department_id), alert: 'Failed to update announcement.'
    end
  end
  
  private
  
  def set_announcement
    @announcement = Announcement.find(params[:id])
  end
  
  def set_department
    @department = if params[:department_id]
                    Department.find(params[:department_id])
                  else
                    current_department
                  end
  end
  
  def announcement_params
    params.require(:announcement).permit(:title, :content, :priority, :pinned, :expires_at, :published_at)
  end
  
  def can_manage_announcements?
    current_user.teacher? || current_user.tutor? || current_user.admin? || current_user.super_admin?
  end
  
  helper_method :can_manage_announcements?
end
