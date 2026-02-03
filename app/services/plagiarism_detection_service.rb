class PlagiarismDetectionService
  include HTTParty
  
  # Configuration for different plagiarism detection services
  TURNITIN_API_URL = 'https://api.turnitin.com/v1/similarity'
  COPYSCAPE_API_URL = 'https://www.copyscape.com/api/'
  
  attr_reader :submission, :detection_provider, :check_external_sources
  
  def initialize(submission, detection_provider: 'internal', check_external_sources: true)
    @submission = submission
    @detection_provider = detection_provider
    @check_external_sources = check_external_sources
  end
  
  def check_plagiarism
    return create_error_result('Submission has no content') if submission.content.blank?
    
    # Create pending plagiarism check
    plagiarism_check = create_plagiarism_check
    
    begin
      # Update status to processing
      plagiarism_check.update!(processing_status: 'processing')
      
      # Perform different types of checks
      internal_results = check_internal_submissions
      external_results = check_external_sources? ? check_external_sources_api : {}
      ai_detection_results = detect_ai_generated_content
      
      # Combine and analyze results
      analysis_results = analyze_plagiarism_results(internal_results, external_results, ai_detection_results)
      
      # Update plagiarism check with results
      plagiarism_check.update!(
        similarity_percentage: analysis_results[:overall_similarity],
        flagged_sections: analysis_results[:flagged_sections].to_json,
        sources_found: analysis_results[:sources].to_json,
        ai_detection_results: ai_detection_results.to_json,
        processing_status: 'completed',
        processed_at: Time.current,
        requires_review: analysis_results[:requires_review]
      )
      
      # Send notifications if high similarity detected
      notify_instructors_if_needed(plagiarism_check)
      
      plagiarism_check
      
    rescue => e
      Rails.logger.error "Plagiarism check failed for submission #{submission.id}: #{e.message}"
      
      plagiarism_check.update!(
        processing_status: 'failed',
        sources_found: { error: e.message }.to_json
      )
      
      plagiarism_check
    end
  end
  
  def bulk_check_assignment(assignment)
    results = []
    
    assignment.submissions.includes(:plagiarism_checks).each do |sub|
      # Skip if already checked recently
      next if sub.plagiarism_checks.where('created_at > ?', 24.hours.ago).exists?
      
      service = self.class.new(sub, detection_provider: detection_provider)
      results << service.check_plagiarism
    end
    
    results
  end
  
  private
  
  def create_plagiarism_check
    PlagiarismCheck.create!(
      submission: submission,
      similarity_percentage: 0,
      processing_status: 'pending'
    )
  end
  
  def create_error_result(error_message)
    PlagiarismCheck.create!(
      submission: submission,
      similarity_percentage: 0,
      sources_found: { error: error_message }.to_json,
      processing_status: 'failed'
    )
  end
  
  def check_internal_submissions
    # Check against other submissions in the same course/assignment
    similar_submissions = find_similar_internal_submissions
    
    internal_results = {
      matches: [],
      max_similarity: 0
    }
    
    similar_submissions.each do |other_submission|
      similarity = calculate_text_similarity(submission.content, other_submission.content)
      
      if similarity > 0.3 # 30% similarity threshold
        match_data = {
          submission_id: other_submission.id,
          student_name: other_submission.user.name,
          similarity_percentage: (similarity * 100).round(2),
          matched_sections: find_matching_sections(submission.content, other_submission.content),
          submission_date: other_submission.created_at
        }
        
        internal_results[:matches] << match_data
        internal_results[:max_similarity] = [internal_results[:max_similarity], similarity].max
      end
    end
    
    internal_results
  end
  
  def find_similar_internal_submissions
    # Get other submissions from the same assignment and course
    course_submissions = submission.assignment.course.submissions
                                  .joins(:assignment)
                                  .where.not(id: submission.id)
                                  .where.not(content: [nil, ''])
    
    # Also check submissions from similar assignments (same course, similar titles)
    similar_assignments = submission.assignment.course.assignments
                                   .where.not(id: submission.assignment.id)
                                   .where('similarity(title, ?) > 0.3', submission.assignment.title)
    
    similar_submissions = Submission.where(assignment: similar_assignments)
                                   .where.not(content: [nil, ''])
    
    (course_submissions + similar_submissions).uniq
  end
  
  def calculate_text_similarity(text1, text2)
    # Implement Jaccard similarity with n-grams
    text1_ngrams = generate_ngrams(normalize_text(text1), 3)
    text2_ngrams = generate_ngrams(normalize_text(text2), 3)
    
    intersection = text1_ngrams & text2_ngrams
    union = text1_ngrams | text2_ngrams
    
    return 0 if union.empty?
    
    intersection.size.to_f / union.size
  end
  
  def normalize_text(text)
    # Remove punctuation, extra spaces, and convert to lowercase
    text.downcase
        .gsub(/[^\w\s]/, ' ')
        .gsub(/\s+/, ' ')
        .strip
  end
  
  def generate_ngrams(text, n)
    words = text.split
    return [] if words.length < n
    
    (0..words.length - n).map do |i|
      words[i, n].join(' ')
    end
  end
  
  def find_matching_sections(text1, text2, min_length: 50)
    # Find common substrings of significant length
    matching_sections = []
    
    # Use a sliding window approach
    words1 = normalize_text(text1).split
    words2 = normalize_text(text2).split
    
    min_words = [min_length / 6, 5].max # Roughly 6 chars per word
    
    (0..words1.length - min_words).each do |i|
      window = words1[i, min_words].join(' ')
      
      match_index = words2.join(' ').index(window)
      if match_index
        matching_sections << {
          text: window,
          position_in_submission: i,
          length: min_words
        }
      end
    end
    
    matching_sections
  end
  
  def check_external_sources_api
    case detection_provider
    when 'turnitin'
      check_turnitin
    when 'copyscape'
      check_copyscape
    else
      check_web_search
    end
  end
  
  def check_turnitin
    # Implementation for Turnitin API
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{Rails.application.credentials.turnitin_api_key}"
    }
    
    body = {
      submission: {
        title: submission.assignment.title,
        author: submission.user.name,
        content: submission.content
      },
      settings: {
        repository: 'STANDARD',
        exclude_quotes: true,
        exclude_bibliography: true
      }
    }
    
    response = HTTParty.post(TURNITIN_API_URL, headers: headers, body: body.to_json)
    
    if response.success?
      parse_turnitin_response(response.parsed_response)
    else
      Rails.logger.error "Turnitin API error: #{response.body}"
      { matches: [], max_similarity: 0 }
    end
  end
  
  def check_copyscape
    # Implementation for Copyscape API
    api_key = Rails.application.credentials.copyscape_api_key
    
    params = {
      u: Rails.application.credentials.copyscape_username,
      k: api_key,
      o: 'csearch',
      t: submission.content[0..10000], # Limit content length
      f: 'json'
    }
    
    response = HTTParty.get(COPYSCAPE_API_URL, query: params)
    
    if response.success?
      parse_copyscape_response(response.parsed_response)
    else
      Rails.logger.error "Copyscape API error: #{response.body}"
      { matches: [], max_similarity: 0 }
    end
  end
  
  def check_web_search
    # Fallback web search using Google Custom Search API
    api_key = Rails.application.credentials.google_api_key
    search_engine_id = Rails.application.credentials.google_search_engine_id
    
    # Extract key phrases from submission
    key_phrases = extract_key_phrases(submission.content)
    
    external_matches = []
    
    key_phrases.each do |phrase|
      next if phrase.length < 20 # Skip short phrases
      
      search_url = "https://www.googleapis.com/customsearch/v1"
      params = {
        key: api_key,
        cx: search_engine_id,
        q: "\"#{phrase}\"",
        num: 5
      }
      
      response = HTTParty.get(search_url, query: params)
      
      if response.success? && response.parsed_response['items']
        response.parsed_response['items'].each do |item|
          external_matches << {
            url: item['link'],
            title: item['title'],
            snippet: item['snippet'],
            matched_phrase: phrase
          }
        end
      end
      
      # Rate limiting
      sleep(0.1)
    end
    
    {
      matches: external_matches,
      max_similarity: external_matches.any? ? 0.5 : 0
    }
  end
  
  def extract_key_phrases(text, min_length: 20, max_phrases: 10)
    # Extract meaningful phrases that could be searched
    sentences = text.split(/[.!?]+/)
    
    phrases = sentences.select { |s| s.strip.length >= min_length }
                      .map(&:strip)
                      .first(max_phrases)
    
    phrases
  end
  
  def detect_ai_generated_content
    # Check for AI-generated content patterns
    ai_indicators = {
      repetitive_patterns: check_repetitive_patterns,
      unnatural_language: check_unnatural_language,
      consistent_quality: check_consistent_quality,
      typical_ai_phrases: check_ai_phrases
    }
    
    ai_probability = calculate_ai_probability(ai_indicators)
    
    {
      probability: ai_probability,
      indicators: ai_indicators,
      confidence: ai_probability > 0.7 ? 'high' : ai_probability > 0.4 ? 'medium' : 'low'
    }
  end
  
  def check_repetitive_patterns
    # Check for repetitive sentence structures
    sentences = submission.content.split(/[.!?]+/).map(&:strip)
    return 0 if sentences.length < 5
    
    # Simple check for similar sentence lengths and structures
    avg_length = sentences.map(&:length).sum.to_f / sentences.length
    length_variance = sentences.map { |s| (s.length - avg_length) ** 2 }.sum / sentences.length
    
    # Lower variance might indicate AI generation
    1.0 - (length_variance / (avg_length * 10)).clamp(0, 1)
  end
  
  def check_unnatural_language
    # Check for overly formal or unnatural language patterns
    formal_words = %w[furthermore moreover consequently nevertheless nonetheless subsequently]
    transition_phrases = ['in conclusion', 'in summary', 'to summarize', 'in other words']
    
    formal_count = formal_words.count { |word| submission.content.downcase.include?(word) }
    transition_count = transition_phrases.count { |phrase| submission.content.downcase.include?(phrase) }
    
    total_words = submission.content.split.length
    
    (formal_count + transition_count * 2).to_f / [total_words / 100, 1].max
  end
  
  def check_consistent_quality
    # Check if writing quality is consistently high throughout
    paragraphs = submission.content.split(/\n\s*\n/)
    return 0 if paragraphs.length < 3
    
    # Simple heuristic: check for consistent sentence complexity
    complexities = paragraphs.map { |p| calculate_paragraph_complexity(p) }
    complexity_variance = complexities.map { |c| (c - complexities.sum.to_f / complexities.length) ** 2 }.sum / complexities.length
    
    # Lower variance in complexity might indicate AI
    1.0 - (complexity_variance / 10).clamp(0, 1)
  end
  
  def calculate_paragraph_complexity(paragraph)
    sentences = paragraph.split(/[.!?]+/)
    return 0 if sentences.empty?
    
    avg_sentence_length = sentences.map { |s| s.split.length }.sum.to_f / sentences.length
    avg_sentence_length / 20 # Normalize
  end
  
  def check_ai_phrases
    # Check for phrases commonly used by AI
    ai_phrases = [
      'as an ai', 'i apologize', 'i understand', 'it\'s important to note',
      'in today\'s world', 'it is worth noting', 'furthermore', 'moreover'
    ]
    
    content_lower = submission.content.downcase
    phrase_count = ai_phrases.count { |phrase| content_lower.include?(phrase) }
    
    [phrase_count.to_f / 10, 1.0].min
  end
  
  def calculate_ai_probability(indicators)
    # Weight different indicators
    weights = {
      repetitive_patterns: 0.2,
      unnatural_language: 0.3,
      consistent_quality: 0.3,
      typical_ai_phrases: 0.2
    }
    
    weighted_sum = indicators.sum { |key, value| weights[key] * value }
    [weighted_sum, 1.0].min
  end
  
  def analyze_plagiarism_results(internal_results, external_results, ai_detection_results)
    # Combine all results into a comprehensive analysis
    all_matches = (internal_results[:matches] || []) + (external_results[:matches] || [])
    
    overall_similarity = [
      internal_results[:max_similarity] || 0,
      external_results[:max_similarity] || 0,
      ai_detection_results[:probability] || 0
    ].max
    
    # Create flagged sections
    flagged_sections = []
    
    # Add internal matches
    (internal_results[:matches] || []).each do |match|
      match[:matched_sections]&.each do |section|
        flagged_sections << {
          type: 'internal_plagiarism',
          text: section[:text],
          similarity: match[:similarity_percentage],
          source: "Submission by #{match[:student_name]}",
          position: section[:position_in_submission]
        }
      end
    end
    
    # Add external matches
    (external_results[:matches] || []).each do |match|
      flagged_sections << {
        type: 'external_plagiarism',
        text: match[:matched_phrase] || match[:snippet],
        source: match[:url] || match[:title],
        similarity: 50 # Estimated
      }
    end
    
    # Add AI detection flags
    if ai_detection_results[:probability] > 0.5
      flagged_sections << {
        type: 'ai_generated',
        text: 'Entire submission flagged for potential AI generation',
        probability: ai_detection_results[:probability],
        confidence: ai_detection_results[:confidence],
        indicators: ai_detection_results[:indicators]
      }
    end
    
    # Determine if review is required
    requires_review = overall_similarity > 0.3 || # 30% similarity
                     ai_detection_results[:probability] > 0.5 || # 50% AI probability
                     flagged_sections.length > 3
    
    {
      overall_similarity: (overall_similarity * 100).round(2),
      flagged_sections: flagged_sections,
      sources: all_matches,
      requires_review: requires_review,
      total_flags: flagged_sections.length
    }
  end
  
  def parse_turnitin_response(response)
    # Parse Turnitin API response
    matches = (response['matches'] || []).map do |match|
      {
        url: match['url'],
        title: match['title'],
        similarity: match['percentage'],
        matched_text: match['text']
      }
    end
    
    {
      matches: matches,
      max_similarity: matches.map { |m| m[:similarity] }.max || 0
    }
  end
  
  def parse_copyscape_response(response)
    # Parse Copyscape API response
    matches = (response['result'] || []).map do |match|
      {
        url: match['url'],
        title: match['title'],
        similarity: match['percent'],
        matched_text: match['textmatches']
      }
    end
    
    {
      matches: matches,
      max_similarity: matches.map { |m| m[:similarity] }.max || 0
    }
  end
  
  def notify_instructors_if_needed(plagiarism_check)
    return unless plagiarism_check.requires_review?
    
    # Notify course instructors about high similarity
    instructors = submission.assignment.course.users.where(role: 'instructor')
    
    instructors.each do |instructor|
      PlagiarismAlertMailer.high_similarity_detected(
        instructor,
        submission,
        plagiarism_check
      ).deliver_later
    end
    
    # Create notification record
    Notification.create!(
      user: submission.assignment.course.instructor,
      title: 'Plagiarism Detected',
      message: "High similarity (#{plagiarism_check.similarity_percentage}%) detected in submission by #{submission.user.name}",
      notification_type: 'plagiarism_alert',
      related_object: plagiarism_check
    )
  end
  
  # Class methods for batch operations
  def self.batch_check_course(course, detection_provider: 'internal')
    results = []
    
    course.assignments.includes(submissions: :plagiarism_checks).each do |assignment|
      assignment.submissions.each do |submission|
        next if submission.plagiarism_checks.where('created_at > ?', 7.days.ago).exists?
        
        service = new(submission, detection_provider: detection_provider)
        results << service.check_plagiarism
      end
    end
    
    results
  end
  
  def self.recheck_flagged_submissions(days_back: 30)
    # Recheck submissions that were previously flagged
    flagged_checks = PlagiarismCheck.where(
      'created_at > ? AND (similarity_percentage > 30 OR requires_review = true)',
      days_back.days.ago
    )
    
    flagged_checks.includes(:submission).each do |check|
      next if check.submission.nil?
      
      service = new(check.submission)
      service.check_plagiarism
    end
  end
end