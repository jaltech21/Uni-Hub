# app/jobs/update_document_content_job.rb
class UpdateDocumentContentJob < ApplicationJob
  queue_as :default

  def perform(document, change_data)
    return unless document && change_data

    operation = change_data['operation']
    position = change_data['position'].to_i
    content = change_data['content']
    
    # Get current document content
    current_content = document.content || ''
    
    # Apply the operation to the content
    new_content = apply_operation(current_content, operation, position, content)
    
    # Update the document with debouncing to avoid too many saves
    cache_key = "document_content_#{document.class.name.downcase}_#{document.id}"
    
    # Store the new content in cache temporarily
    Rails.cache.write(cache_key, new_content, expires_in: 30.seconds)
    
    # Schedule a delayed save to batch multiple changes
    UpdateDocumentContentSaveJob.set(wait: 5.seconds).perform_later(document, cache_key)
    
  rescue => e
    Rails.logger.error "Failed to update document content: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def apply_operation(content, operation, position, new_content)
    case operation
    when 'insert'
      # Insert new content at position
      content.insert(position, new_content)
    when 'delete'
      # Delete content from position
      content.slice!(position, new_content.to_i) # new_content contains length to delete
      content
    when 'replace'
      # Replace content at position
      length = new_content.is_a?(Hash) ? new_content['length'].to_i : new_content.length
      content[position, length] = new_content.is_a?(Hash) ? new_content['text'] : new_content
      content
    else
      content
    end
  end
end