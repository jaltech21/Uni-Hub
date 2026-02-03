class OperationalTransformer
  def initialize(base_operation, concurrent_operation = nil)
    @base_operation = base_operation
    @concurrent_operation = concurrent_operation
  end
  
  def transform
    return single_operation_transform if @concurrent_operation.nil?
    
    # Operational Transformation (OT) between two concurrent operations
    case [@base_operation.operation_type, @concurrent_operation.operation_type]
    when ['insert', 'insert']
      transform_insert_insert
    when ['insert', 'delete']
      transform_insert_delete
    when ['delete', 'insert']
      transform_delete_insert
    when ['delete', 'delete']
      transform_delete_delete
    when ['insert', 'replace']
      transform_insert_replace
    when ['replace', 'insert']
      transform_replace_insert
    when ['replace', 'replace']
      transform_replace_replace
    when ['delete', 'replace']
      transform_delete_replace
    when ['replace', 'delete']
      transform_replace_delete
    else
      transform_generic_operations
    end
  end
  
  def transform_operation_against_history(operations_history)
    transformed_operation = @base_operation
    transformation_log = []
    
    operations_history.each do |historical_op|
      next if historical_op.sequence_number >= @base_operation.sequence_number
      
      transformer = OperationalTransformer.new(transformed_operation, historical_op)
      result = transformer.transform
      
      if result[:success]
        transformed_operation = create_operation_from_data(result[:transformed_operation])
        transformation_log << result[:log_entry]
      else
        return {
          success: false,
          error: result[:error],
          conflict_info: result[:conflict_info]
        }
      end
    end
    
    {
      success: true,
      transformed_operation: transformed_operation.operation_data,
      transformation_log: transformation_log,
      original_operation: @base_operation.operation_data
    }
  end
  
  private
  
  def single_operation_transform
    # No concurrent operation, just validate the single operation
    {
      success: true,
      transformed_operation: @base_operation.operation_data,
      log_entry: {
        type: 'no_transform_needed',
        operation_id: @base_operation.operation_id,
        timestamp: Time.current
      }
    }
  end
  
  def transform_insert_insert
    base_pos = @base_operation.start_position
    concurrent_pos = @concurrent_operation.start_position
    
    if base_pos <= concurrent_pos
      # Base operation comes first, no transformation needed
      success_result(@base_operation.operation_data, 'insert_insert_no_change')
    else
      # Concurrent operation affects base operation's position
      concurrent_length = @concurrent_operation.operation_data['text']&.length || 0
      new_position = base_pos + concurrent_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_position'] = base_pos
      
      success_result(
        transformed_data,
        'insert_insert_position_shifted',
        {
          position_shift: concurrent_length,
          new_position: new_position
        }
      )
    end
  end
  
  def transform_insert_delete
    insert_pos = @base_operation.start_position
    delete_start = @concurrent_operation.start_position
    delete_end = @concurrent_operation.end_position
    
    if insert_pos <= delete_start
      # Insert happens before delete, no transformation needed
      success_result(@base_operation.operation_data, 'insert_delete_no_change')
    elsif insert_pos > delete_end
      # Insert happens after delete, shift position back
      delete_length = delete_end - delete_start
      new_position = insert_pos - delete_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_position'] = insert_pos
      
      success_result(
        transformed_data,
        'insert_delete_position_shifted',
        { position_shift: -delete_length, new_position: new_position }
      )
    else
      # Insert happens within deleted range - conflict!
      conflict_result('insert_within_deleted_range', {
        insert_position: insert_pos,
        deleted_range: [delete_start, delete_end]
      })
    end
  end
  
  def transform_delete_insert
    delete_start = @base_operation.start_position
    delete_end = @base_operation.end_position
    insert_pos = @concurrent_operation.start_position
    
    if insert_pos <= delete_start
      # Insert happens before delete, shift delete range forward
      insert_length = @concurrent_operation.operation_data['text']&.length || 0
      new_start = delete_start + insert_length
      new_end = delete_end + insert_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_range'] = [delete_start, delete_end]
      
      success_result(
        transformed_data,
        'delete_insert_range_shifted',
        {
          range_shift: insert_length,
          new_range: [new_start, new_end]
        }
      )
    elsif insert_pos >= delete_end
      # Insert happens after delete, no transformation needed
      success_result(@base_operation.operation_data, 'delete_insert_no_change')
    else
      # Insert happens within delete range, split the delete
      insert_length = @concurrent_operation.operation_data['text']&.length || 0
      
      # Split into two delete operations
      first_delete_end = insert_pos
      second_delete_start = insert_pos
      second_delete_end = delete_end + insert_length
      
      transformed_data = {
        type: 'split_delete',
        first_delete: {
          start_position: delete_start,
          end_position: first_delete_end,
          deleted_text: @base_operation.operation_data['deleted_text'][0...(insert_pos - delete_start)]
        },
        second_delete: {
          start_position: second_delete_start,
          end_position: second_delete_end,
          deleted_text: @base_operation.operation_data['deleted_text'][(insert_pos - delete_start)..-1]
        }
      }
      
      success_result(
        transformed_data,
        'delete_insert_split_delete',
        { split_at: insert_pos, insert_length: insert_length }
      )
    end
  end
  
  def transform_delete_delete
    base_start = @base_operation.start_position
    base_end = @base_operation.end_position
    concurrent_start = @concurrent_operation.start_position
    concurrent_end = @concurrent_operation.end_position
    
    # Check for overlap
    if base_end <= concurrent_start || concurrent_end <= base_start
      # No overlap, adjust positions if needed
      if concurrent_end <= base_start
        # Concurrent delete happens before base delete
        concurrent_length = concurrent_end - concurrent_start
        new_start = base_start - concurrent_length
        new_end = base_end - concurrent_length
        
        transformed_data = @base_operation.operation_data.dup
        transformed_data['original_range'] = [base_start, base_end]
        
        success_result(
          transformed_data,
          'delete_delete_position_shifted',
          {
            position_shift: -concurrent_length,
            new_range: [new_start, new_end]
          }
        )
      else
        # Concurrent delete happens after base delete, no change needed
        success_result(@base_operation.operation_data, 'delete_delete_no_change')
      end
    else
      # Overlapping deletes - complex case
      transform_overlapping_deletes(base_start, base_end, concurrent_start, concurrent_end)
    end
  end
  
  def transform_overlapping_deletes(base_start, base_end, concurrent_start, concurrent_end)
    # Find the union of both delete ranges
    union_start = [base_start, concurrent_start].min
    union_end = [base_end, concurrent_end].max
    
    # Calculate what's actually left to delete after concurrent operation
    if concurrent_start <= base_start && concurrent_end >= base_end
      # Concurrent delete completely contains base delete - base becomes no-op
      success_result(
        { type: 'no_op', reason: 'completely_deleted_by_concurrent' },
        'delete_delete_no_op'
      )
    elsif base_start < concurrent_start && base_end > concurrent_end
      # Base delete contains concurrent delete - adjust base delete
      concurrent_length = concurrent_end - concurrent_start
      new_end = base_end - concurrent_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_range'] = [base_start, base_end]
      
      success_result(
        transformed_data,
        'delete_delete_range_reduced',
        {
          reduced_by: concurrent_length,
          new_range: [base_start, new_end]
        }
      )
    else
      # Partial overlap - create a new delete range
      if base_start < concurrent_start
        # Keep the part before concurrent delete
        new_end = concurrent_start
        transformed_data = @base_operation.operation_data.dup
        transformed_data['original_range'] = [base_start, base_end]
        
        success_result(
          transformed_data,
          'delete_delete_partial_overlap_before',
          { new_range: [base_start, new_end] }
        )
      else
        # Keep the part after concurrent delete (adjusted for concurrent delete)
        concurrent_length = concurrent_end - concurrent_start
        new_start = concurrent_start
        new_end = base_end - concurrent_length
        
        if new_start >= new_end
          # Nothing left to delete
          success_result(
            { type: 'no_op', reason: 'overlap_eliminated_range' },
            'delete_delete_no_op'
          )
        else
          transformed_data = @base_operation.operation_data.dup
          transformed_data['original_range'] = [base_start, base_end]
          
          success_result(
            transformed_data,
            'delete_delete_partial_overlap_after',
            { new_range: [new_start, new_end] }
          )
        end
      end
    end
  end
  
  def transform_insert_replace
    insert_pos = @base_operation.start_position
    replace_start = @concurrent_operation.start_position
    replace_end = @concurrent_operation.end_position
    
    if insert_pos <= replace_start
      # Insert before replace, no transformation needed
      success_result(@base_operation.operation_data, 'insert_replace_no_change')
    elsif insert_pos > replace_end
      # Insert after replace, adjust position for replacement length change
      old_length = replace_end - replace_start
      new_length = @concurrent_operation.operation_data['new_text']&.length || 0
      length_change = new_length - old_length
      new_position = insert_pos + length_change
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_position'] = insert_pos
      
      success_result(
        transformed_data,
        'insert_replace_position_adjusted',
        {
          position_change: length_change,
          new_position: new_position
        }
      )
    else
      # Insert within replace range - conflict!
      conflict_result('insert_within_replaced_range', {
        insert_position: insert_pos,
        replaced_range: [replace_start, replace_end]
      })
    end
  end
  
  def transform_replace_insert
    replace_start = @base_operation.start_position
    replace_end = @base_operation.end_position
    insert_pos = @concurrent_operation.start_position
    
    if insert_pos <= replace_start
      # Insert before replace, shift replace range
      insert_length = @concurrent_operation.operation_data['text']&.length || 0
      new_start = replace_start + insert_length
      new_end = replace_end + insert_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_range'] = [replace_start, replace_end]
      
      success_result(
        transformed_data,
        'replace_insert_range_shifted',
        {
          range_shift: insert_length,
          new_range: [new_start, new_end]
        }
      )
    elsif insert_pos >= replace_end
      # Insert after replace, no transformation needed
      success_result(@base_operation.operation_data, 'replace_insert_no_change')
    else
      # Insert within replace range, incorporate into replacement
      insert_text = @concurrent_operation.operation_data['text'] || ''
      insert_offset = insert_pos - replace_start
      
      original_new_text = @base_operation.operation_data['new_text'] || ''
      updated_new_text = original_new_text[0...insert_offset] + 
                        insert_text + 
                        original_new_text[insert_offset..-1]
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['new_text'] = updated_new_text
      transformed_data['incorporated_insert'] = {
        text: insert_text,
        position: insert_offset
      }
      
      success_result(
        transformed_data,
        'replace_insert_incorporated',
        { incorporated_text: insert_text, at_offset: insert_offset }
      )
    end
  end
  
  def transform_replace_replace
    base_start = @base_operation.start_position
    base_end = @base_operation.end_position
    concurrent_start = @concurrent_operation.start_position
    concurrent_end = @concurrent_operation.end_position
    
    if base_end <= concurrent_start || concurrent_end <= base_start
      # No overlap
      if concurrent_end <= base_start
        # Concurrent replace happens before base replace
        concurrent_old_length = concurrent_end - concurrent_start
        concurrent_new_length = @concurrent_operation.operation_data['new_text']&.length || 0
        length_change = concurrent_new_length - concurrent_old_length
        
        new_start = base_start + length_change
        new_end = base_end + length_change
        
        transformed_data = @base_operation.operation_data.dup
        transformed_data['original_range'] = [base_start, base_end]
        
        success_result(
          transformed_data,
          'replace_replace_position_adjusted',
          {
            position_change: length_change,
            new_range: [new_start, new_end]
          }
        )
      else
        # Concurrent replace happens after base replace, no change needed
        success_result(@base_operation.operation_data, 'replace_replace_no_change')
      end
    else
      # Overlapping replaces - conflict!
      conflict_result('overlapping_replaces', {
        base_range: [base_start, base_end],
        concurrent_range: [concurrent_start, concurrent_end],
        overlap_start: [base_start, concurrent_start].max,
        overlap_end: [base_end, concurrent_end].min
      })
    end
  end
  
  def transform_delete_replace
    delete_start = @base_operation.start_position
    delete_end = @base_operation.end_position
    replace_start = @concurrent_operation.start_position
    replace_end = @concurrent_operation.end_position
    
    if delete_end <= replace_start
      # Delete happens before replace, no transformation needed
      success_result(@base_operation.operation_data, 'delete_replace_no_change')
    elsif delete_start >= replace_end
      # Delete happens after replace, adjust position
      replace_old_length = replace_end - replace_start
      replace_new_length = @concurrent_operation.operation_data['new_text']&.length || 0
      length_change = replace_new_length - replace_old_length
      
      new_start = delete_start + length_change
      new_end = delete_end + length_change
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_range'] = [delete_start, delete_end]
      
      success_result(
        transformed_data,
        'delete_replace_position_adjusted',
        {
          position_change: length_change,
          new_range: [new_start, new_end]
        }
      )
    else
      # Delete overlaps with replace - conflict!
      conflict_result('delete_overlaps_replace', {
        delete_range: [delete_start, delete_end],
        replace_range: [replace_start, replace_end]
      })
    end
  end
  
  def transform_replace_delete
    replace_start = @base_operation.start_position
    replace_end = @base_operation.end_position
    delete_start = @concurrent_operation.start_position
    delete_end = @concurrent_operation.end_position
    
    if replace_end <= delete_start
      # Replace happens before delete, no transformation needed
      success_result(@base_operation.operation_data, 'replace_delete_no_change')
    elsif replace_start >= delete_end
      # Replace happens after delete, adjust position
      delete_length = delete_end - delete_start
      new_start = replace_start - delete_length
      new_end = replace_end - delete_length
      
      transformed_data = @base_operation.operation_data.dup
      transformed_data['original_range'] = [replace_start, replace_end]
      
      success_result(
        transformed_data,
        'replace_delete_position_adjusted',
        {
          position_shift: -delete_length,
          new_range: [new_start, new_end]
        }
      )
    else
      # Replace overlaps with delete - conflict!
      conflict_result('replace_overlaps_delete', {
        replace_range: [replace_start, replace_end],
        delete_range: [delete_start, delete_end]
      })
    end
  end
  
  def transform_generic_operations
    # Handle other operation types or format/move operations
    if operations_affect_same_content?
      conflict_result('generic_operation_conflict', {
        base_operation: @base_operation.operation_type,
        concurrent_operation: @concurrent_operation.operation_type,
        content_path: @base_operation.content_path
      })
    else
      success_result(@base_operation.operation_data, 'generic_operations_no_conflict')
    end
  end
  
  def operations_affect_same_content?
    return false unless @base_operation.content_path == @concurrent_operation.content_path
    
    # Check if operations affect overlapping content areas
    base_range = (@base_operation.start_position || 0)..(@base_operation.end_position || 0)
    concurrent_range = (@concurrent_operation.start_position || 0)..(@concurrent_operation.end_position || 0)
    
    base_range.overlap?(concurrent_range)
  end
  
  def success_result(transformed_data, transform_type, additional_info = {})
    {
      success: true,
      transformed_operation: transformed_data,
      log_entry: {
        type: transform_type,
        base_operation_id: @base_operation.operation_id,
        concurrent_operation_id: @concurrent_operation&.operation_id,
        timestamp: Time.current,
        additional_info: additional_info
      }
    }
  end
  
  def conflict_result(conflict_type, conflict_info)
    {
      success: false,
      conflict_info: {
        type: conflict_type,
        base_operation: {
          id: @base_operation.operation_id,
          type: @base_operation.operation_type,
          user_id: @base_operation.user_id,
          sequence: @base_operation.sequence_number
        },
        concurrent_operation: {
          id: @concurrent_operation&.operation_id,
          type: @concurrent_operation&.operation_type,
          user_id: @concurrent_operation&.user_id,
          sequence: @concurrent_operation&.sequence_number
        },
        details: conflict_info,
        detected_at: Time.current
      }
    }
  end
  
  def create_operation_from_data(operation_data)
    # Create a temporary operation object for further transformations
    EditOperation.new(
      collaborative_session: @base_operation.collaborative_session,
      user: @base_operation.user,
      operation_type: @base_operation.operation_type,
      operation_data: operation_data,
      content_path: @base_operation.content_path,
      start_position: operation_data['start_position'] || @base_operation.start_position,
      end_position: operation_data['end_position'] || @base_operation.end_position,
      sequence_number: @base_operation.sequence_number,
      timestamp: @base_operation.timestamp
    )
  end
end