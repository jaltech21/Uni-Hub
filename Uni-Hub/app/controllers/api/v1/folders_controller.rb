module Api
  module V1
    class FoldersController < BaseController
      before_action :set_folder, only: [:update, :destroy]

      def index
        render_success(current_user.folders.ordered.map { |f| serialize_folder(f) })
      end

      def create
        folder = current_user.folders.build(folder_params)
        if folder.save
          render_success(serialize_folder(folder), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: folder.errors.messages
          )
        end
      end

      def update
        if @folder.update(folder_params)
          render_success(serialize_folder(@folder))
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: @folder.errors.messages
          )
        end
      end

      def destroy
        @folder.destroy
        render_message("Folder deleted successfully")
      end

      private

      def set_folder
        @folder = current_user.folders.find(params[:id])
      end

      def folder_params
        params.expect(folder: {}).permit(:name, :description, :color, :position)
      end

      def serialize_folder(folder)
        {
          id: folder.id,
          name: folder.name,
          description: folder.description,
          notes_count: folder.notes_count,
          created_at: folder.created_at,
          updated_at: folder.updated_at
        }
      end
    end
  end
end