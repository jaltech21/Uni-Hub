class AiGradingService
  include HTTParty
  
  # Configuration for different AI services
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
  
  attr_reader :submission, :rubric, :ai_provider
  
  def initialize(submission, rubric, ai_provider: 'openai')
    @submission = submission
    @rubric = rubric
    @ai_provider = ai_provider
  end
  
  def grade_submission
    return create_error_result('Rubric is not AI-enabled') unless rubric.ai_grading_enabled?
    return create_error_result('Submission has no content') if submission.content.blank?
    
    # Create pending grading result
    grading_result = create_grading_result
    
    begin
      # Update status to processing
      grading_result.update!(processing_status: 'processing')
      
      # Prepare AI prompt
      prompt = build_grading_prompt
      
      # Get AI response
      ai_response = send_to_ai_service(prompt)
      
      # Parse AI response
      parsed_response = parse_ai_response(ai_response)
      
      # Update grading result with AI feedback
      grading_result.update!(
        ai_score: parsed_response[:total_score],
        ai_feedback: parsed_response[:feedback].to_json,
        confidence_score: parsed_response[:confidence],
        processing_status: 'completed',
        processed_at: Time.current
      )
      
      # Check if plagiarism check is needed
      schedule_plagiarism_check if should_check_plagiarism?
      
      grading_result
      
    rescue => e
      Rails.logger.error "AI Grading failed for submission #{submission.id}: #{e.message}"
      
      grading_result.update!(
        processing_status: 'failed',
        ai_feedback: { error: e.message }.to_json
      )
      
      grading_result
    end
  end
  
  def grade_batch(submissions)
    results = []
    
    submissions.each do |sub|
      service = self.class.new(sub, rubric, ai_provider: ai_provider)
      results << service.grade_submission
    end
    
    results
  end
  
  private
  
  def create_grading_result
    AiGradingResult.create!(
      submission: submission,
      grading_rubric: rubric,
      ai_score: 0,
      confidence_score: 0,
      processing_status: 'pending'
    )
  end
  
  def create_error_result(error_message)
    AiGradingResult.create!(
      submission: submission,
      grading_rubric: rubric,
      ai_score: 0,
      ai_feedback: { error: error_message }.to_json,
      confidence_score: 0,
      processing_status: 'failed'
    )
  end
  
  def build_grading_prompt
    base_prompt = rubric.generate_ai_prompt
    
    submission_content = format_submission_content
    
    prompt = base_prompt + "\n\nSUBMISSION TO GRADE:\n"
    prompt += "Title: #{submission.assignment.title}\n"
    prompt += "Student: #{submission.user.name}\n"
    prompt += "Submitted: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}\n\n"
    prompt += "Content:\n#{submission_content}\n\n"
    
    # Add context about the assignment
    if submission.assignment.content.present?
      prompt += "ASSIGNMENT INSTRUCTIONS:\n#{submission.assignment.content}\n\n"
    end
    
    prompt += build_response_format_instructions
    
    prompt
  end
  
  def format_submission_content
    content = submission.content
    
    # If submission has file attachments, include information about them
    if submission.respond_to?(:attachments) && submission.attachments.any?
      content += "\n\nATTACHED FILES:\n"
      submission.attachments.each do |attachment|
        content += "- #{attachment.filename} (#{attachment.content_type})\n"
      end
    end
    
    # Truncate very long submissions for API limits
    if content.length > 10000
      content = content[0..9900] + "\n\n[Content truncated for length]"
    end
    
    content
  end
  
  def build_response_format_instructions
    criteria_names = rubric.criteria_list.map { |c| c['name'] }
    
    instructions = "\nPLEASE RESPOND WITH A JSON OBJECT IN THE FOLLOWING FORMAT:\n"
    instructions += "{\n"
    instructions += "  \"criterion_scores\": {\n"
    
    criteria_names.each_with_index do |name, index|
      instructions += "    \"#{name}\": {\n"
      instructions += "      \"score\": [numeric score],\n"
      instructions += "      \"feedback\": \"[specific feedback for this criterion]\"\n"
      instructions += "    }"
      instructions += index < criteria_names.length - 1 ? ",\n" : "\n"
    end
    
    instructions += "  },\n"
    instructions += "  \"total_score\": [sum of all criterion scores],\n"
    instructions += "  \"overall_feedback\": \"[comprehensive feedback on the entire submission]\",\n"
    instructions += "  \"strengths\": [\"strength 1\", \"strength 2\", ...],\n"
    instructions += "  \"areas_for_improvement\": [\"improvement 1\", \"improvement 2\", ...],\n"
    instructions += "  \"suggestions\": [\"suggestion 1\", \"suggestion 2\", ...],\n"
    instructions += "  \"confidence\": [confidence score between 0.0 and 1.0]\n"
    instructions += "}\n\n"
    instructions += "IMPORTANT: Provide constructive, specific feedback that helps the student improve."
    
    instructions
  end
  
  def send_to_ai_service(prompt)
    case ai_provider
    when 'openai'
      send_to_openai(prompt)
    when 'anthropic'
      send_to_anthropic(prompt)
    else
      raise "Unsupported AI provider: #{ai_provider}"
    end
  end
  
  def send_to_openai(prompt)
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{Rails.application.credentials.openai_api_key}"
    }
    
    body = {
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: 'You are an expert educational assessor. Grade submissions fairly and provide constructive feedback.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 2000
    }
    
    response = HTTParty.post(OPENAI_API_URL, headers: headers, body: body.to_json)
    
    if response.success?
      response.parsed_response.dig('choices', 0, 'message', 'content')
    else
      raise "OpenAI API error: #{response.body}"
    end
  end
  
  def send_to_anthropic(prompt)
    headers = {
      'Content-Type' => 'application/json',
      'x-api-key' => Rails.application.credentials.anthropic_api_key,
      'anthropic-version' => '2023-06-01'
    }
    
    body = {
      model: 'claude-3-sonnet-20240229',
      max_tokens: 2000,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    }
    
    response = HTTParty.post(ANTHROPIC_API_URL, headers: headers, body: body.to_json)
    
    if response.success?
      response.parsed_response.dig('content', 0, 'text')
    else
      raise "Anthropic API error: #{response.body}"
    end
  end
  
  def parse_ai_response(ai_response)
    # Try to parse JSON response
    begin
      parsed = JSON.parse(ai_response)
      
      # Validate required fields
      total_score = parsed['total_score'] || calculate_total_from_criteria(parsed['criterion_scores'])
      confidence = parsed['confidence'] || estimate_confidence(parsed)
      
      {
        total_score: [total_score, rubric.total_points].min, # Cap at max points
        feedback: parsed,
        confidence: [confidence, 1.0].min # Cap at 1.0
      }
      
    rescue JSON::ParserError
      # Fallback to text parsing
      parse_text_response(ai_response)
    end
  end
  
  def parse_text_response(response)
    # Extract score from text
    score_match = response.match(/(?:total|final|overall).+?(\d+(?:\.\d+)?)/i)
    total_score = score_match ? score_match[1].to_f : estimate_score_from_text(response)
    
    # Extract confidence if mentioned
    confidence_match = response.match(/confidence.+?(\d+(?:\.\d+)?)/i)
    confidence = confidence_match ? confidence_match[1].to_f : 0.7
    
    # Normalize confidence to 0-1 range
    confidence = confidence > 1 ? confidence / 100 : confidence
    
    {
      total_score: [total_score, rubric.total_points].min,
      feedback: {
        overall_feedback: response,
        format: 'text'
      },
      confidence: [confidence, 1.0].min
    }
  end
  
  def calculate_total_from_criteria(criterion_scores)
    return 0 unless criterion_scores.is_a?(Hash)
    
    criterion_scores.values.sum do |criterion|
      if criterion.is_a?(Hash) && criterion['score']
        criterion['score'].to_f
      else
        0
      end
    end
  end
  
  def estimate_confidence(parsed_response)
    # Estimate confidence based on response completeness
    confidence = 0.5
    
    confidence += 0.2 if parsed_response['criterion_scores'].present?
    confidence += 0.1 if parsed_response['overall_feedback'].present?
    confidence += 0.1 if parsed_response['strengths'].present?
    confidence += 0.1 if parsed_response['suggestions'].present?
    
    confidence
  end
  
  def estimate_score_from_text(response)
    # Simple heuristic scoring based on positive/negative language
    positive_words = %w[excellent good great strong well effective clear]
    negative_words = %w[poor weak unclear ineffective lacking inadequate]
    
    positive_count = positive_words.count { |word| response.downcase.include?(word) }
    negative_count = negative_words.count { |word| response.downcase.include?(word) }
    
    # Calculate rough percentage
    if positive_count > negative_count
      percentage = [70 + (positive_count - negative_count) * 5, 95].min
    else
      percentage = [60 - (negative_count - positive_count) * 5, 30].max
    end
    
    (rubric.total_points * percentage / 100).round(1)
  end
  
  def should_check_plagiarism?
    # Check if plagiarism detection is enabled for this assignment
    submission.assignment.respond_to?(:plagiarism_detection_enabled?) &&
    submission.assignment.plagiarism_detection_enabled? &&
    !submission.plagiarism_checks.exists?
  end
  
  def schedule_plagiarism_check
    PlagiarismCheckJob.perform_later(submission.id)
  end
  
  # Utility methods for different grading approaches
  def self.batch_grade_assignment(assignment, ai_provider: 'openai')
    return [] unless assignment.grading_rubrics.ai_enabled.any?
    
    rubric = assignment.grading_rubrics.ai_enabled.first
    submissions = assignment.submissions.where.not(id: AiGradingResult.pluck(:submission_id))
    
    results = []
    submissions.find_each do |submission|
      service = new(submission, rubric, ai_provider: ai_provider)
      results << service.grade_submission
    end
    
    results
  end
  
  def self.regrade_with_updated_rubric(rubric)
    # Regrade all submissions for assignments using this rubric
    submissions = Submission.joins(assignment: :grading_rubrics)
                           .where(grading_rubrics: { id: rubric.id })
    
    submissions.find_each do |submission|
      service = new(submission, rubric)
      service.grade_submission
    end
  end
end