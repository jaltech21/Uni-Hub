module Api
  module V1
    class NotesController < BaseController
      before_action :set_note, only: [:show, :update, :destroy]

      def index
        notes = policy_scope(Note).includes(:folder, :tags)
        notes = notes.in_folder(params[:folder_id])   if params[:folder_id].present?
        notes = notes.tagged_with(params[:tag])       if params[:tag].present?
        notes = notes.search(params[:search])         if params[:search].present?
        notes = notes.recent

        paginated = paginate(notes)
        render_success(
          paginated.map { |n| serialize_note(n) },
          meta: pagination_meta(paginated)
        )
      end

      def show
        authorize @note
        render_success(serialize_note(@note, include_sharing: true))
      end

      def create
        note = current_user.notes.new(note_attributes)
        authorize note

        if note.save
          apply_tags(note, params[:tags]) if params.key?(:tags)
          render_success(serialize_note(note.reload, include_sharing: true), status: :created)
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: note.errors.messages
          )
        end
      end

      def update
        authorize @note

        if @note.update(note_attributes)
          apply_tags(@note, params[:tags]) if params.key?(:tags)
          render_success(serialize_note(@note.reload, include_sharing: true))
        else
          render_error(
            "Validation failed",
            status: :unprocessable_entity,
            code: "VALIDATION_ERROR",
            errors: @note.errors.messages
          )
        end
      end

      def destroy
        authorize @note
        @note.destroy!
        render_message("Note deleted successfully")
      end

      private

      def set_note
        @note = Note.find(params[:id])
      end

      def note_attributes
        params.permit(:title, :content, :folder_id, :department_id)
      end

      def apply_tags(note, raw_tags)
        names = Array(raw_tags).flat_map { |t| t.to_s.split(",") }.map(&:strip).reject(&:empty?)
        note.tag_list = names
      end

      def serialize_note(note, include_sharing: false)
        payload = {
          id: note.id,
          title: note.title,
          content: note.content,
          folder_id: note.folder_id,
          folder_name: note.folder&.name,
          tags: note.tags.map { |t| { id: t.id, name: t.name } },
          created_at: note.created_at,
          updated_at: note.updated_at
        }
        if include_sharing
          payload[:shared_with] = note.shared_with_users.map do |u|
            { id: u.id, name: u.full_name, email: u.email }
          end
        end
        payload
      end
    end
  end
end
