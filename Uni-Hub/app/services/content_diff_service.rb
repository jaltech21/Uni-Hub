class ContentDiffService
  def initialize(version1, version2)
    @version1 = version1
    @version2 = version2
  end
  
  def generate_diff
    {
      summary: generate_summary,
      changes: calculate_changes,
      statistics: generate_statistics,
      generated_at: Time.current
    }
  end
  
  def detailed_comparison
    {
      basic_info: compare_basic_info,
      content_changes: compare_content_fields,
      structural_changes: compare_structure,
      metadata_changes: compare_metadata,
      visual_diff: generate_visual_diff,
      statistics: generate_comparison_statistics
    }
  end
  
  def generate_html_diff
    content1 = extract_main_content(@version1)
    content2 = extract_main_content(@version2)
    
    # Use a diff gem like 'diffy' for better HTML diff generation
    require 'diffy'
    
    Diffy::Diff.new(content1, content2, format: :html, include_plus_and_minus_in_html: true).to_s
  rescue LoadError
    # Fallback to simple diff if diffy gem not available
    simple_text_diff(content1, content2)
  end
  
  def generate_word_diff
    content1 = extract_main_content(@version1)
    content2 = extract_main_content(@version2)
    
    words1 = content1.split(/\s+/)
    words2 = content2.split(/\s+/)
    
    generate_word_level_diff(words1, words2)
  end
  
  private
  
  def generate_summary
    changes = calculate_changes
    
    summary_parts = []
    
    if changes[:added].any?
      summary_parts << "#{changes[:added].count} additions"
    end
    
    if changes[:removed].any?
      summary_parts << "#{changes[:removed].count} deletions"
    end
    
    if changes[:modified].any?
      summary_parts << "#{changes[:modified].count} modifications"
    end
    
    if summary_parts.empty?
      'No changes detected'
    else
      summary_parts.join(', ')
    end
  end
  
  def calculate_changes
    data1 = @version1.content_data
    data2 = @version2.content_data
    
    changes = {
      added: [],
      removed: [],
      modified: []
    }
    
    # Find additions (keys in data2 but not in data1)
    (data2.keys - data1.keys).each do |key|
      changes[:added] << {
        field: key,
        value: data2[key],
        type: determine_change_type(key, nil, data2[key])
      }
    end
    
    # Find removals (keys in data1 but not in data2)
    (data1.keys - data2.keys).each do |key|
      changes[:removed] << {
        field: key,
        value: data1[key],
        type: determine_change_type(key, data1[key], nil)
      }
    end
    
    # Find modifications (keys in both but with different values)
    (data1.keys & data2.keys).each do |key|
      if data1[key] != data2[key]
        changes[:modified] << {
          field: key,
          old_value: data1[key],
          new_value: data2[key],
          type: determine_change_type(key, data1[key], data2[key]),
          change_details: analyze_field_change(key, data1[key], data2[key])
        }
      end
    end
    
    changes
  end
  
  def generate_statistics
    data1 = @version1.content_data
    data2 = @version2.content_data
    
    {
      version1: {
        word_count: count_words_in_data(data1),
        character_count: count_characters_in_data(data1),
        fields_count: data1.keys.count
      },
      version2: {
        word_count: count_words_in_data(data2),
        character_count: count_characters_in_data(data2),
        fields_count: data2.keys.count
      },
      changes: {
        fields_added: (data2.keys - data1.keys).count,
        fields_removed: (data1.keys - data2.keys).count,
        fields_modified: (data1.keys & data2.keys).select { |k| data1[k] != data2[k] }.count
      }
    }
  end
  
  def compare_basic_info
    {
      version1: {
        tag: @version1.version_tag,
        author: @version1.user.name,
        created_at: @version1.created_at,
        status: @version1.status,
        summary: @version1.change_summary
      },
      version2: {
        tag: @version2.version_tag,
        author: @version2.user.name,
        created_at: @version2.created_at,
        status: @version2.status,
        summary: @version2.change_summary
      },
      time_difference: @version2.created_at - @version1.created_at
    }
  end
  
  def compare_content_fields
    important_fields = %w[title description content body instructions]
    comparisons = {}
    
    important_fields.each do |field|
      value1 = @version1.content_data[field]
      value2 = @version2.content_data[field]
      
      if value1 != value2
        comparisons[field] = {
          old_value: value1,
          new_value: value2,
          change_type: determine_field_change_type(value1, value2),
          word_diff: generate_word_diff_for_field(value1, value2)
        }
      end
    end
    
    comparisons
  end
  
  def compare_structure
    structural_fields = %w[questions sections parts chapters attachments]
    changes = {}
    
    structural_fields.each do |field|
      old_structure = @version1.content_data[field]
      new_structure = @version2.content_data[field]
      
      if old_structure != new_structure
        changes[field] = analyze_structural_change(old_structure, new_structure)
      end
    end
    
    changes
  end
  
  def compare_metadata
    metadata_changes = {}
    
    @version1.metadata.each do |key, value|
      new_value = @version2.metadata[key]
      if value != new_value
        metadata_changes[key] = {
          old_value: value,
          new_value: new_value
        }
      end
    end
    
    # Check for new metadata
    @version2.metadata.each do |key, value|
      unless @version1.metadata.key?(key)
        metadata_changes[key] = {
          old_value: nil,
          new_value: value
        }
      end
    end
    
    metadata_changes
  end
  
  def generate_visual_diff
    main_content1 = extract_main_content(@version1)
    main_content2 = extract_main_content(@version2)
    
    {
      html_diff: generate_html_diff_content(main_content1, main_content2),
      side_by_side: {
        left: main_content1,
        right: main_content2
      },
      unified: generate_unified_diff(main_content1, main_content2)
    }
  end
  
  def generate_comparison_statistics
    stats1 = @version1.content_statistics
    stats2 = @version2.content_statistics
    
    {
      word_count_change: stats2[:word_count] - stats1[:word_count],
      character_count_change: stats2[:character_count] - stats1[:character_count],
      structure_elements_change: stats2[:structure_elements] - stats1[:structure_elements],
      attachments_change: stats2[:attachments] - stats1[:attachments],
      percentage_change: calculate_percentage_change(stats1, stats2)
    }
  end
  
  def determine_change_type(field, old_value, new_value)
    case field
    when 'title', 'description'
      'content'
    when 'due_date', 'time_limit'
      'metadata'
    when 'questions', 'sections'
      'structure'
    when 'attachments'
      'media'
    else
      'general'
    end
  end
  
  def analyze_field_change(field, old_value, new_value)
    case field
    when 'title', 'description', 'content', 'body', 'instructions'
      analyze_text_change(old_value, new_value)
    when 'questions', 'sections'
      analyze_array_change(old_value, new_value)
    when 'attachments'
      analyze_attachments_change(old_value, new_value)
    else
      { type: 'value_change', old: old_value, new: new_value }
    end
  end
  
  def analyze_text_change(old_text, new_text)
    return { type: 'no_change' } if old_text == new_text
    
    old_text = old_text.to_s
    new_text = new_text.to_s
    
    old_words = old_text.split
    new_words = new_text.split
    
    {
      type: 'text_change',
      word_count_change: new_words.length - old_words.length,
      character_count_change: new_text.length - old_text.length,
      similarity_percentage: calculate_text_similarity(old_text, new_text)
    }
  end
  
  def analyze_array_change(old_array, new_array)
    old_array = Array(old_array)
    new_array = Array(new_array)
    
    {
      type: 'array_change',
      items_added: new_array.length - old_array.length,
      items_removed: old_array - new_array,
      items_added_list: new_array - old_array,
      reordered: old_array.sort != new_array.sort && old_array.length == new_array.length
    }
  end
  
  def analyze_attachments_change(old_attachments, new_attachments)
    old_attachments = Array(old_attachments)
    new_attachments = Array(new_attachments)
    
    old_files = old_attachments.map { |a| a['filename'] }
    new_files = new_attachments.map { |a| a['filename'] }
    
    {
      type: 'attachments_change',
      files_added: new_files - old_files,
      files_removed: old_files - new_files,
      total_size_change: calculate_size_change(old_attachments, new_attachments)
    }
  end
  
  def analyze_structural_change(old_structure, new_structure)
    old_structure = Array(old_structure)
    new_structure = Array(new_structure)
    
    {
      elements_added: new_structure.length - old_structure.length,
      elements_reordered: old_structure != new_structure && old_structure.sort == new_structure.sort,
      content_modified: old_structure.sort != new_structure.sort
    }
  end
  
  def count_words_in_data(data)
    text_content = extract_text_from_data(data)
    text_content.split.length
  end
  
  def count_characters_in_data(data)
    text_content = extract_text_from_data(data)
    text_content.length
  end
  
  def extract_text_from_data(data)
    return '' unless data.is_a?(Hash)
    
    text_fields = %w[title description content body instructions]
    text_parts = text_fields.map { |field| data[field] }.compact
    
    text = text_parts.join(' ')
    ActionView::Base.full_sanitizer.sanitize(text)
  end
  
  def extract_main_content(version)
    data = version.content_data
    main_fields = %w[title description content body instructions]
    
    main_fields.map { |field| data[field] }.compact.join("\n\n")
  end
  
  def determine_field_change_type(old_value, new_value)
    return 'addition' if old_value.nil? || old_value.to_s.empty?
    return 'deletion' if new_value.nil? || new_value.to_s.empty?
    'modification'
  end
  
  def generate_word_diff_for_field(old_value, new_value)
    return nil if old_value == new_value
    
    old_words = old_value.to_s.split
    new_words = new_value.to_s.split
    
    generate_word_level_diff(old_words, new_words)
  end
  
  def generate_word_level_diff(words1, words2)
    # Simple implementation - could be enhanced with more sophisticated algorithms
    added_words = words2 - words1
    removed_words = words1 - words2
    
    {
      added: added_words,
      removed: removed_words,
      unchanged: words1 & words2
    }
  end
  
  def simple_text_diff(text1, text2)
    lines1 = text1.split("\n")
    lines2 = text2.split("\n")
    
    # Simple line-by-line diff
    diff_lines = []
    
    max_lines = [lines1.length, lines2.length].max
    
    (0...max_lines).each do |i|
      line1 = lines1[i]
      line2 = lines2[i]
      
      if line1 == line2
        diff_lines << { type: 'unchanged', content: line1 }
      elsif line1.nil?
        diff_lines << { type: 'added', content: line2 }
      elsif line2.nil?
        diff_lines << { type: 'removed', content: line1 }
      else
        diff_lines << { type: 'removed', content: line1 }
        diff_lines << { type: 'added', content: line2 }
      end
    end
    
    diff_lines
  end
  
  def generate_unified_diff(text1, text2)
    lines1 = text1.split("\n")
    lines2 = text2.split("\n")
    
    # This is a simplified unified diff format
    # A full implementation would use proper diff algorithms
    {
      header: "--- Version #{@version1.version_tag}\n+++ Version #{@version2.version_tag}",
      lines: simple_text_diff(text1, text2)
    }
  end
  
  def calculate_text_similarity(text1, text2)
    return 100.0 if text1 == text2
    return 0.0 if text1.empty? && text2.empty?
    
    # Simple similarity calculation based on common words
    words1 = text1.downcase.split
    words2 = text2.downcase.split
    
    return 0.0 if words1.empty? || words2.empty?
    
    common_words = words1 & words2
    total_unique_words = (words1 | words2).length
    
    (common_words.length.to_f / total_unique_words * 100).round(2)
  end
  
  def calculate_size_change(old_attachments, new_attachments)
    old_size = old_attachments.sum { |a| a['byte_size'] || 0 }
    new_size = new_attachments.sum { |a| a['byte_size'] || 0 }
    
    new_size - old_size
  end
  
  def calculate_percentage_change(stats1, stats2)
    word_change = stats1[:word_count] > 0 ? 
      ((stats2[:word_count] - stats1[:word_count]).to_f / stats1[:word_count] * 100).round(2) : 0
    
    char_change = stats1[:character_count] > 0 ? 
      ((stats2[:character_count] - stats1[:character_count]).to_f / stats1[:character_count] * 100).round(2) : 0
    
    {
      word_count: word_change,
      character_count: char_change
    }
  end
  
  def generate_html_diff_content(content1, content2)
    # This would generate HTML with highlighted changes
    # For now, return a simple structure
    {
      removed_sections: content1.split("\n").map.with_index { |line, i| { line_number: i + 1, content: line } },
      added_sections: content2.split("\n").map.with_index { |line, i| { line_number: i + 1, content: line } }
    }
  end
end