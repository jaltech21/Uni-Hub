class FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_folder, only: [:update, :destroy]
  
  def index
    @folders = current_user.folders.ordered
    render json: @folders
  end

  def create
    @folder = current_user.folders.build(folder_params)
    
    if @folder.save
      respond_to do |format|
        format.html { redirect_to notes_path, notice: 'Folder created successfully.' }
        format.json { render json: @folder, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to notes_path, alert: @folder.errors.full_messages.join(', ') }
        format.json { render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @folder.update(folder_params)
      respond_to do |format|
        format.html { redirect_to notes_path, notice: 'Folder updated successfully.' }
        format.json { render json: @folder }
      end
    else
      respond_to do |format|
        format.html { redirect_to notes_path, alert: @folder.errors.full_messages.join(', ') }
        format.json { render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @folder.destroy
    respond_to do |format|
      format.html { redirect_to notes_path, notice: 'Folder deleted successfully.' }
      format.json { head :no_content }
    end
  end

  private

  def set_folder
    @folder = current_user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :color, :position)
  end
end
