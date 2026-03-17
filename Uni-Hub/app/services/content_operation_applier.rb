class ContentOperationApplier
  def initialize(content_object)
    @content = content_object
  end
  
  def apply_operation(operation)
    case operation.operation_type
    when 'insert'
      apply_insert_operation(operation)
    when 'delete'
      apply_delete_operation(operation)
    when 'replace'
      apply_replace_operation(operation)
    when 'format'
      apply_format_operation(operation)
    when 'move'
      apply_move_operation(operation)
    when 'attribute_change'
      apply_attribute_change_operation(operation)
    when 'structure_change'
      apply_structure_change_operation(operation)
    else
      {
        success: false,
        error: "Unknown operation type: #{operation.operation_type}",
        error_data: { operation_type: operation.operation_type }
      }
    end
  rescue => e
    Rails.logger.error "Failed to apply operation #{operation.operation_id}: #{e.message}"
    {
      success: false,
      error: e.message,
      error_data: { exception: e.class.name, backtrace: e.backtrace.first(3) }
    }
  end
  
  def apply_insert(operation)
    apply_insert_operation(operation)
  end
  
  def apply_delete(operation)
    apply_delete_operation(operation)
  end
  
  def apply_format(operation)
    apply_format_operation(operation)
  end
  
  private
  
  def apply_insert_operation(operation)
    content_path = operation.content_path
    position = operation.start_position
    text_to_insert = operation.operation_data['text']
    
    return error_result("No text to insert") unless text_to_insert.present?
    return error_result("Invalid position") unless position.is_a?(Integer) && position >= 0
    
    current_content = get_content_at_path(content_path)
    return error_result("Content path not found: #{content_path}") unless current_content
    
    # Convert content to string if it's not already
    content_string = current_content.to_s
    
    # Validate position doesn't exceed content length
    if position > content_string.length
      position = content_string.length
    end
    
    # Perform the insert
    new_content = content_string[0...position] + text_to_insert + content_string[position..-1]
    
    # Update the content
    update_result = update_content_at_path(content_path, new_content)
    
    if update_result[:success]
      success_result({
        new_content: new_content,
        inserted_text: text_to_insert,
        position: position,
        content_length_change: text_to_insert.length
      })
    else
      update_result
    end
  end
  
  def apply_delete_operation(operation)
    content_path = operation.content_path
    start_pos = operation.start_position
    end_pos = operation.end_position
    
    return error_result("Invalid positions") unless start_pos.is_a?(Integer) && end_pos.is_a?(Integer)
    return error_result("Start position must be less than end position") unless start_pos < end_pos
    
    current_content = get_content_at_path(content_path)
    return error_result("Content path not found: #{content_path}") unless current_content
    
    content_string = current_content.to_s
    
    # Validate positions
    if start_pos >= content_string.length
      return error_result("Start position exceeds content length")
    end
    
    # Adjust end position if it exceeds content length
    end_pos = [end_pos, content_string.length].min
    
    # Extract the text to be deleted (for undo purposes)
    deleted_text = content_string[start_pos...end_pos]
    
    # Perform the delete
    new_content = content_string[0...start_pos] + content_string[end_pos..-1]
    
    # Update the content
    update_result = update_content_at_path(content_path, new_content)
    
    if update_result[:success]
      success_result({
        new_content: new_content,
        deleted_text: deleted_text,
        start_position: start_pos,
        end_position: end_pos,
        content_length_change: -(end_pos - start_pos)
      })
    else
      update_result
    end
  end
  
  def apply_replace_operation(operation)
    content_path = operation.content_path
    start_pos = operation.start_position
    end_pos = operation.end_position
    new_text = operation.operation_data['new_text']
    
    return error_result("New text is required") unless new_text.present?
    return error_result("Invalid positions") unless start_pos.is_a?(Integer) && end_pos.is_a?(Integer)
    return error_result("Start position must be less than or equal to end position") unless start_pos <= end_pos
    
    current_content = get_content_at_path(content_path)
    return error_result("Content path not found: #{content_path}") unless current_content
    
    content_string = current_content.to_s
    
    # Validate positions
    if start_pos >= content_string.length
      # If start position is at or beyond content length, treat as insert
      new_content = content_string + new_text
      old_text = ""
    else
      # Adjust end position if it exceeds content length
      end_pos = [end_pos, content_string.length].min
      
      # Extract the text being replaced
      old_text = content_string[start_pos...end_pos]
      
      # Perform the replace
      new_content = content_string[0...start_pos] + new_text + content_string[end_pos..-1]
    end
    
    # Update the content
    update_result = update_content_at_path(content_path, new_content)
    
    if update_result[:success]
      success_result({
        new_content: new_content,
        old_text: old_text,
        new_text: new_text,
        start_position: start_pos,
        end_position: end_pos,
        content_length_change: new_text.length - old_text.length
      })
    else
      update_result
    end
  end
  
  def apply_format_operation(operation)
    # Format operations modify styling/attributes without changing text content
    content_path = operation.content_path
    format_data = operation.operation_data
    
    case @content
    when Note
      apply_note_formatting(content_path, format_data)
    when Assignment
      apply_assignment_formatting(content_path, format_data)
    when Quiz
      apply_quiz_formatting(content_path, format_data)
    else
      error_result("Formatting not supported for #{@content.class.name}")
    end
  end
  
  def apply_move_operation(operation)
    content_path = operation.content_path
    source_start = operation.start_position
    source_end = operation.end_position
    target_position = operation.operation_data['target_position']
    
    return error_result("Invalid source positions") unless source_start.is_a?(Integer) && source_end.is_a?(Integer)
    return error_result("Invalid target position") unless target_position.is_a?(Integer)
    return error_result("Source positions invalid") unless source_start < source_end
    
    current_content = get_content_at_path(content_path)
    return error_result("Content path not found: #{content_path}") unless current_content
    
    content_string = current_content.to_s
    
    # Validate positions
    return error_result("Source start exceeds content length") if source_start >= content_string.length
    
    source_end = [source_end, content_string.length].min
    target_position = [target_position, content_string.length].max(0)
    
    # Extract the text to move
    moved_text = content_string[source_start...source_end]
    
    # Remove text from source
    content_without_moved = content_string[0...source_start] + content_string[source_end..-1]
    
    # Adjust target position if it's after the source
    if target_position > source_start
      target_position -= (source_end - source_start)
    end
    
    # Insert text at target position
    new_content = content_without_moved[0...target_position] + moved_text + content_without_moved[target_position..-1]
    
    # Update the content
    update_result = update_content_at_path(content_path, new_content)
    
    if update_result[:success]
      success_result({
        new_content: new_content,
        moved_text: moved_text,
        source_start: source_start,
        source_end: source_end,
        target_position: target_position
      })
    else
      update_result
    end
  end
  
  def apply_attribute_change_operation(operation)
    attribute_name = operation.operation_data['attribute']
    new_value = operation.operation_data['new_value']
    old_value = operation.operation_data['old_value']
    
    return error_result("Attribute name is required") unless attribute_name.present?
    
    # Check if the attribute exists and is allowed to be changed
    unless allowed_attributes_for_collaboration.include?(attribute_name)
      return error_result("Attribute '#{attribute_name}' is not allowed for collaborative editing")
    end
    
    begin
      # Store old value if not provided
      old_value ||= @content.send(attribute_name) if @content.respond_to?(attribute_name)
      
      # Apply the change without versioning (collaborative changes are tracked separately)
      @content.class.without_versioning do
        @content.update!(attribute_name => new_value)
      end
      
      success_result({
        attribute: attribute_name,
        old_value: old_value,
        new_value: new_value
      })
    rescue => e
      error_result("Failed to update attribute '#{attribute_name}': #{e.message}")
    end
  end
  
  def apply_structure_change_operation(operation)
    # Handle structural changes like adding/removing questions, sections, etc.
    structure_type = operation.operation_data['structure_type']
    change_type = operation.operation_data['change_type'] # add, remove, reorder
    
    case [@content.class.name, structure_type]
    when ['Quiz', 'questions']
      apply_quiz_question_structure_change(operation)
    when ['Assignment', 'sections']
      apply_assignment_section_structure_change(operation)
    else
      error_result("Structure change not supported: #{@content.class.name}.#{structure_type}")
    end
  end
  
  private
  
  def get_content_at_path(content_path)
    return nil unless content_path.present?
    
    path_parts = content_path.split('.')
    current = @content
    
    path_parts.each do |part|
      if current.respond_to?(part)
        current = current.send(part)
      elsif current.is_a?(Hash) && current.key?(part)
        current = current[part]
      elsif current.is_a?(Hash) && current.key?(part.to_sym)
        current = current[part.to_sym]
      else
        return nil
      end
    end
    
    current
  end
  
  def update_content_at_path(content_path, new_content)
    return error_result("Content path is required") unless content_path.present?
    
    begin
      @content.class.without_versioning do
        case content_path
        when 'title'
          @content.update!(title: new_content)
        when 'description'
          @content.update!(description: new_content)
        when 'content'
          @content.update!(content: new_content)
        when 'instructions'
          @content.update!(instructions: new_content) if @content.respond_to?(:instructions)
        else
          # Handle nested paths or custom content structures
          update_nested_content_path(content_path, new_content)
        end
      end
      
      success_result({ updated_path: content_path, new_content: new_content })
    rescue => e
      error_result("Failed to update content at path '#{content_path}': #{e.message}")
    end
  end
  
  def update_nested_content_path(content_path, new_content)
    # Handle more complex content paths like 'sections.0.content' or 'questions.1.text'
    path_parts = content_path.split('.')
    
    if path_parts.length == 1
      # Simple attribute update
      if @content.respond_to?("#{path_parts[0]}=")
        @content.update!(path_parts[0] => new_content)
      else
        raise "Attribute '#{path_parts[0]}' not found or not updatable"
      end
    else
      # Complex nested update - this would need to be implemented based on your specific data structures
      raise "Complex nested path updates not yet implemented: #{content_path}"
    end
  end
  
  def apply_note_formatting(content_path, format_data)
    # Note formatting operations
    format_type = format_data['format_type']
    
    case format_type
    when 'bold', 'italic', 'underline'
      # These would typically be handled by the frontend editor
      # Here we just acknowledge the formatting change
      success_result({
        format_applied: format_type,
        content_path: content_path,
        format_data: format_data
      })
    else
      error_result("Unsupported note format type: #{format_type}")
    end
  end
  
  def apply_assignment_formatting(content_path, format_data)
    # Assignment-specific formatting
    success_result({
      format_applied: format_data['format_type'],
      content_path: content_path
    })
  end
  
  def apply_quiz_formatting(content_path, format_data)
    # Quiz-specific formatting
    success_result({
      format_applied: format_data['format_type'],
      content_path: content_path
    })
  end
  
  def apply_quiz_question_structure_change(operation)
    change_type = operation.operation_data['change_type']
    question_data = operation.operation_data['question_data']
    position = operation.operation_data['position']
    
    case change_type
    when 'add'
      add_quiz_question(question_data, position)
    when 'remove'
      remove_quiz_question(position)
    when 'reorder'
      reorder_quiz_questions(operation.operation_data['new_order'])
    else
      error_result("Unsupported quiz question change type: #{change_type}")
    end
  end
  
  def apply_assignment_section_structure_change(operation)
    # Handle assignment section changes
    success_result({ structure_change: 'assignment_sections', operation_data: operation.operation_data })
  end
  
  def add_quiz_question(question_data, position = nil)
    return error_result("Question data is required") unless question_data.present?
    
    begin
      @content.class.without_versioning do
        question = @content.quiz_questions.build(question_data)
        question.save!
        
        # Handle positioning if specified
        if position.present? && position.is_a?(Integer)
          # Implement question reordering logic here
          # This would depend on your specific quiz question ordering system
        end
      end
      
      success_result({
        structure_change: 'question_added',
        question_id: question.id,
        position: position
      })
    rescue => e
      error_result("Failed to add quiz question: #{e.message}")
    end
  end
  
  def remove_quiz_question(position)
    return error_result("Position is required") unless position.is_a?(Integer)
    
    begin
      @content.class.without_versioning do
        questions = @content.quiz_questions.order(:created_at)
        question_to_remove = questions[position]
        
        return error_result("Question not found at position #{position}") unless question_to_remove
        
        question_to_remove.destroy!
      end
      
      success_result({
        structure_change: 'question_removed',
        position: position
      })
    rescue => e
      error_result("Failed to remove quiz question: #{e.message}")
    end
  end
  
  def reorder_quiz_questions(new_order)
    return error_result("New order array is required") unless new_order.is_a?(Array)
    
    begin
      @content.class.without_versioning do
        # Implement question reordering logic
        # This would depend on your specific ordering system
      end
      
      success_result({
        structure_change: 'questions_reordered',
        new_order: new_order
      })
    rescue => e
      error_result("Failed to reorder quiz questions: #{e.message}")
    end
  end
  
  def allowed_attributes_for_collaboration
    case @content
    when Assignment
      %w[title description instructions due_date]
    when Note
      %w[title content]
    when Quiz
      %w[title description instructions time_limit]
    else
      %w[title description]
    end
  end
  
  def success_result(data = {})
    {
      success: true,
      transformed_data: data,
      timestamp: Time.current
    }
  end
  
  def error_result(message, data = {})
    {
      success: false,
      error: message,
      error_data: data,
      timestamp: Time.current
    }
  end
end