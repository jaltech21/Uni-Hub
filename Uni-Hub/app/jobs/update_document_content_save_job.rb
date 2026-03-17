# app/jobs/update_document_content_save_job.rb
class UpdateDocumentContentSaveJob < ApplicationJob
  queue_as :default

  def perform(document, cache_key)
    return unless document && cache_key

    # Get the latest content from cache
    latest_content = Rails.cache.read(cache_key)
    return unless latest_content

    # Only save if content has actually changed
    if document.content != latest_content
      document.update_column(:content, latest_content)
      document.touch # Update the updated_at timestamp
      
      Rails.logger.info "Document #{document.class.name} #{document.id} content saved"
      
      # Broadcast save notification to collaborators
      document_channel = "collaboration_#{document.class.name.downcase}_#{document.id}"
      
      ActionCable.server.broadcast(document_channel, {
        type: 'document_auto_saved',
        saved_at: document.updated_at,
        version: document.updated_at.to_i
      })
    end
    
    # Clean up cache
    Rails.cache.delete(cache_key)
    
  rescue => e
    Rails.logger.error "Failed to save document content: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end