# frozen_string_literal: true

# OpenAI Service for AI-powered features
# Handles text summarization, question generation, and other AI operations
class OpenAiService
  include Singleton

  RATE_LIMIT = 50 # requests per minute (increased for development)
  RATE_WINDOW = 60 # seconds

  attr_reader :client, :mock_mode

  def initialize
    # Enable mock mode if explicitly set or if no API key is configured
    @mock_mode = ENV['AI_MOCK_MODE'] == 'true' || ENV['OPENAI_MOCK_MODE'] == 'true'
    
    api_key = Rails.application.config.openai_api_key || 
              Rails.application.credentials.dig(:openai, :api_key) || 
              ENV['OPENAI_API_KEY']
    
    if api_key.blank?
      Rails.logger.warn("OpenAI API key is not configured! Running in MOCK MODE.")
      @client = nil
      @mock_mode = true
    elsif @mock_mode
      Rails.logger.info("AI Mock Mode ENABLED - will not call OpenAI API")
      @client = nil
    else
      @client = OpenAI::Client.new(
        api_key: api_key,
        timeout: 30
      )
    end
    
    @rate_limiters = {}
  end

  # Summarize text with adjustable length
  # @param text [String] The text to summarize
  # @param length [Symbol] :short, :medium, or :long
  # @param user_id [Integer] Optional user ID for per-user rate limiting
  # @return [Hash] { success: true/false, summary: String, error: String }
  def summarize_text(text, length: :medium, user_id: nil)
    return error_response("Text cannot be empty") if text.blank?
    return error_response("Text is too short to summarize") if text.length < 100
    
    # Handle mock mode
    if @mock_mode
      return handle_mock_summarize(text, length, user_id)
    end
    
    return error_response("OpenAI API is not configured") if @client.nil?

    # Check rate limit
    rate_limit_result = check_rate_limit(user_id)
    if !rate_limit_result[:allowed]
      log_ai_failure(user_id, 'summarize_text', 'Rate limit exceeded', rate_limited: true)
      return rate_limit_result
    end

    start_time = Time.current
    log_ai_request(user_id, 'summarize_text', "length: #{length}, text_length: #{text.length}")
    prompt = build_summarization_prompt(text, length)
    
    begin
      response = client.chat.completions.create(
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant that summarizes academic texts clearly and concisely." },
          { role: "user", content: prompt }
        ],
        temperature: 0.5,
        max_tokens: token_limit_for_length(length)
      )

      summary = response.dig("choices", 0, "message", "content")
      tokens = response.dig("usage", "total_tokens")
      
      if summary.present?
        log_ai_success(user_id, 'summarize_text', "summary_length: #{summary.length}", 
                      tokens: tokens, start_time: start_time)
        success_response(summary)
      else
        log_ai_failure(user_id, 'summarize_text', 'Empty response')
        error_response("Failed to generate summary")
      end
    rescue OpenAI::Errors::RateLimitError => e
      error_msg = e.message
      log_ai_failure(user_id, 'summarize_text', "OpenAI API rate limit: #{error_msg}", rate_limited: true)
      Rails.logger.error("OpenAI Rate Limit Error: #{error_msg}")
      
      # Check if it's a quota issue vs rate limit
      if error_msg.include?('quota') || error_msg.include?('insufficient_quota')
        error_response("⚠️ OpenAI API quota exceeded. Your API key has run out of credits. Please add credits to your OpenAI account or contact support.")
      else
        error_response("⚠️ OpenAI API rate limit reached (this is OpenAI's limit, not ours). Please wait a moment and try again.")
      end
    rescue OpenAI::Errors::AuthenticationError => e
      log_ai_failure(user_id, 'summarize_text', "Authentication failed: #{e.message}")
      Rails.logger.error("OpenAI Authentication Error: #{e.message}")
      error_response("🔐 OpenAI API authentication failed. The API key may be invalid or expired. Please contact support.")
    rescue OpenAI::Errors::APIConnectionError, OpenAI::Errors::APITimeoutError => e
      log_ai_failure(user_id, 'summarize_text', "Connection error: #{e.message}")
      Rails.logger.error("OpenAI API Connection Error: #{e.message}")
      error_response("🌐 Failed to connect to OpenAI service. Please check your internet connection and try again.")
    rescue OpenAI::Errors::APIError => e
      log_ai_failure(user_id, 'summarize_text', "API error: #{e.message}")
      Rails.logger.error("OpenAI API Error: #{e.message}")
      error_response("⚠️ OpenAI service error: #{e.message}. Please try again later.")
    rescue StandardError => e
      log_ai_failure(user_id, 'summarize_text', "Unexpected: #{e.message}")
      Rails.logger.error("Unexpected error in summarization: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      error_response("An unexpected error occurred. Please try again.")
    end
  end

  # Generate exam questions from text
  # @param text [String] The text to generate questions from
  # @param question_type [Symbol] :multiple_choice, :short_answer, :true_false, :mixed
  # @param count [Integer] Number of questions to generate
  # @param user_id [Integer] Optional user ID for per-user rate limiting
  # @return [Hash] { success: true/false, questions: Array, error: String }
  def generate_questions(text, question_type: :mixed, count: 5, user_id: nil)
    return error_response("Text cannot be empty") if text.blank?
    return error_response("Text is too short to generate questions") if text.length < 200
    
    # Handle mock mode
    if @mock_mode
      return handle_mock_generate_questions(text, question_type, count, user_id)
    end
    
    return error_response("OpenAI API is not configured") if @client.nil?

    # Check rate limit
    rate_limit_result = check_rate_limit(user_id)
    if !rate_limit_result[:allowed]
      log_ai_failure(user_id, 'generate_questions', 'Rate limit exceeded', rate_limited: true)
      return rate_limit_result
    end

    start_time = Time.current
    log_ai_request(user_id, 'generate_questions', "type: #{question_type}, count: #{count}, text_length: #{text.length}")
    prompt = build_question_prompt(text, question_type, count)

    begin
      response = client.chat.completions.create(
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are an expert educator that creates challenging but fair exam questions. Always provide questions in valid JSON format." },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 1500
      )

      content = response.dig("choices", 0, "message", "content")
      tokens = response.dig("usage", "total_tokens")
      questions = parse_questions(content, question_type)
      
      if questions.present?
        log_ai_success(user_id, 'generate_questions', "Generated #{questions.size} questions", 
                      tokens: tokens, start_time: start_time)
        success_response(questions)
      else
        log_ai_failure(user_id, 'generate_questions', 'Failed to parse questions')
        error_response("Failed to generate questions. Please try again.")
      end
    rescue OpenAI::Errors::RateLimitError => e
      error_msg = e.message
      log_ai_failure(user_id, 'generate_questions', "OpenAI API rate limit: #{error_msg}", rate_limited: true)
      Rails.logger.error("OpenAI Rate Limit Error: #{error_msg}")
      
      # Check if it's a quota issue vs rate limit
      if error_msg.include?('quota') || error_msg.include?('insufficient_quota')
        error_response("⚠️ OpenAI API quota exceeded. Your API key has run out of credits. Please add credits to your OpenAI account or contact support.")
      else
        error_response("⚠️ OpenAI API rate limit reached (this is OpenAI's limit, not ours). Please wait a moment and try again.")
      end
    rescue OpenAI::Errors::AuthenticationError => e
      log_ai_failure(user_id, 'generate_questions', "Authentication failed: #{e.message}")
      Rails.logger.error("OpenAI Authentication Error: #{e.message}")
      error_response("🔐 OpenAI API authentication failed. The API key may be invalid or expired. Please contact support.")
    rescue OpenAI::Errors::APIConnectionError, OpenAI::Errors::APITimeoutError => e
      log_ai_failure(user_id, 'generate_questions', "Connection error: #{e.message}")
      Rails.logger.error("OpenAI API Connection Error: #{e.message}")
      error_response("🌐 Failed to connect to OpenAI service. Please check your internet connection and try again.")
    rescue OpenAI::Errors::APIError => e
      log_ai_failure(user_id, 'generate_questions', "API error: #{e.message}")
      Rails.logger.error("OpenAI API Error: #{e.message}")
      error_response("AI service error. Please try again later.")
    rescue StandardError => e
      log_ai_failure(user_id, 'generate_questions', "Unexpected: #{e.message}")
      Rails.logger.error("Unexpected error in question generation: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      error_response("An unexpected error occurred. Please try again.")
    end
  end

  # Get study hints for a specific topic or question
  # @param topic [String] The topic or question to get hints for
  # @param user_id [Integer] Optional user ID for per-user rate limiting
  # @return [Hash] { success: true/false, hints: Array, error: String }
  def get_study_hints(topic, user_id: nil)
    return error_response("Topic cannot be empty") if topic.blank?
    
    # Handle mock mode
    if @mock_mode
      return handle_mock_study_hints(topic, user_id)
    end
    
    return error_response("OpenAI API is not configured") if @client.nil?

    # Check rate limit
    rate_limit_result = check_rate_limit(user_id)
    if !rate_limit_result[:allowed]
      log_ai_failure(user_id, 'get_study_hints', 'Rate limit exceeded', rate_limited: true)
      return rate_limit_result
    end

    start_time = Time.current
    log_ai_request(user_id, 'get_study_hints', "topic: #{topic}")
    prompt = "Provide 5 helpful study hints for the following topic or question: #{topic}"

    begin
      response = client.chat.completions.create(
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful tutor providing study hints without giving away complete answers." },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 500
      )

      hints_text = response.dig("choices", 0, "message", "content")
      tokens = response.dig("usage", "total_tokens")
      hints = hints_text.split("\n").reject(&:blank?).map { |h| h.gsub(/^\d+\.\s*/, '').strip }
      
      if hints.present?
        log_ai_success(user_id, 'get_study_hints', "Generated #{hints.size} hints", 
                      tokens: tokens, start_time: start_time)
        success_response(hints)
      else
        log_ai_failure(user_id, 'get_study_hints', 'Empty response')
        error_response("Failed to generate hints")
      end
    rescue StandardError => e
      log_ai_failure(user_id, 'get_study_hints', "Error: #{e.message}")
      Rails.logger.error("Error generating hints: #{e.message}")
      error_response("Failed to generate study hints. Please try again.")
    end
  end

  private

  # Mock mode handlers
  def handle_mock_summarize(text, length, user_id)
    start_time = Time.current
    log_ai_request(user_id, 'summarize_text', "[MOCK MODE] length: #{length}, text_length: #{text.length}")
    
    begin
      summary = mock_summarize(text, length)
      log_ai_success(user_id, 'summarize_text', "[MOCK] summary_length: #{summary.length}", 
                    tokens: 150, start_time: start_time)
      success_response(summary)
    rescue StandardError => e
      log_ai_failure(user_id, 'summarize_text', "[MOCK] Error: #{e.message}")
      error_response("Mock summarization failed: #{e.message}")
    end
  end

  def handle_mock_generate_questions(text, question_type, count, user_id)
    start_time = Time.current
    log_ai_request(user_id, 'generate_questions', "[MOCK MODE] type: #{question_type}, count: #{count}")
    
    begin
      questions = mock_generate_questions(text, question_type, count)
      log_ai_success(user_id, 'generate_questions', "[MOCK] Generated #{questions.size} questions", 
                    tokens: 300, start_time: start_time)
      success_response(questions)
    rescue StandardError => e
      log_ai_failure(user_id, 'generate_questions', "[MOCK] Error: #{e.message}")
      error_response("Mock question generation failed: #{e.message}")
    end
  end

  def handle_mock_study_hints(topic, user_id)
    start_time = Time.current
    log_ai_request(user_id, 'get_study_hints', "[MOCK MODE] topic: #{topic}")
    
    begin
      hints = mock_study_hints(topic)
      log_ai_success(user_id, 'get_study_hints', "[MOCK] Generated #{hints.size} hints", 
                    tokens: 100, start_time: start_time)
      success_response(hints)
    rescue StandardError => e
      log_ai_failure(user_id, 'get_study_hints', "[MOCK] Error: #{e.message}")
      error_response("Mock hint generation failed: #{e.message}")
    end
  end

  # Check rate limit and return status hash (doesn't raise exception)
  def check_rate_limit(user_id = nil)
    # Use a default key if no user_id provided (for backwards compatibility)
    limiter_key = user_id || :global
    
    # Create rate limiter for this user if it doesn't exist
    @rate_limiters[limiter_key] ||= RateLimiter.new(RATE_LIMIT, RATE_WINDOW)
    
    limiter = @rate_limiters[limiter_key]
    
    if limiter.allow_request?
      remaining = limiter.remaining_requests
      Rails.logger.info("Rate limit check passed for user #{user_id || 'global'}: #{remaining} requests remaining")
      { allowed: true, remaining: remaining }
    else
      reset_time = limiter.reset_time
      wait_seconds = (reset_time - Time.current).to_i
      Rails.logger.warn("Rate limit exceeded for user #{user_id || 'global'}. Resets in #{wait_seconds}s")
      
      error_response("You've reached the rate limit (#{RATE_LIMIT} requests per minute). Please wait #{wait_seconds} seconds and try again.")
    end
  end

  # Logging methods for monitoring
  def log_ai_request(user_id, action, request_details = nil)
    Rails.logger.info("AI Request - User: #{user_id || 'anonymous'}, Action: #{action}")
    
    # Create database log entry
    return nil unless user_id # Don't log if no user
    
    begin
      AiUsageLog.create!(
        user_id: user_id,
        action: action,
        status: 'pending',
        request_details: request_details.to_s,
        created_at: Time.current
      )
    rescue => e
      Rails.logger.error("Failed to create AI usage log: #{e.message}")
      nil
    end
  end

  def log_ai_success(user_id, action, details = nil, tokens: nil, start_time: nil)
    msg = "AI Success - User: #{user_id || 'anonymous'}, Action: #{action}"
    msg += ", Details: #{details}" if details
    Rails.logger.info(msg)
    
    # Update database log entry
    return unless user_id
    
    begin
      processing_time = start_time ? (Time.current - start_time).round(2) : nil
      
      # Find the most recent pending log for this user and action, or create new one
      log = AiUsageLog.where(user_id: user_id, action: action, status: 'pending')
                       .order(created_at: :desc)
                       .first
      
      if log
        log.update!(
          status: 'success',
          response_details: details.to_s,
          processing_time: processing_time,
          tokens_used: tokens
        )
      else
        # Create new success log if no pending found
        AiUsageLog.create!(
          user_id: user_id,
          action: action,
          status: 'success',
          response_details: details.to_s,
          processing_time: processing_time,
          tokens_used: tokens
        )
      end
    rescue => e
      Rails.logger.error("Failed to update AI usage log: #{e.message}")
    end
  end

  def log_ai_failure(user_id, action, error, rate_limited: false)
    Rails.logger.error("AI Failure - User: #{user_id || 'anonymous'}, Action: #{action}, Error: #{error}")
    
    # Update or create database log entry
    return unless user_id
    
    begin
      status = rate_limited ? 'rate_limited' : 'failure'
      
      # Find the most recent pending log for this user and action
      log = AiUsageLog.where(user_id: user_id, action: action, status: 'pending')
                       .order(created_at: :desc)
                       .first
      
      if log
        log.update!(
          status: status,
          error_message: error.to_s
        )
      else
        # Create new failure log if no pending found
        AiUsageLog.create!(
          user_id: user_id,
          action: action,
          status: status,
          error_message: error.to_s
        )
      end
    rescue => e
      Rails.logger.error("Failed to update AI usage log: #{e.message}")
    end
  end

  def build_summarization_prompt(text, length)
    word_count = case length
                 when :short then "3-5 sentences"
                 when :medium then "1-2 paragraphs"
                 when :long then "3-4 paragraphs"
                 else "1-2 paragraphs"
                 end

    <<~PROMPT
      Please summarize the following text in #{word_count}. 
      Focus on the key points and main ideas. 
      Make it clear and easy to understand for students.

      Text to summarize:
      #{text}
    PROMPT
  end

  def build_question_prompt(text, question_type, count)
    type_instruction = case question_type
                       when :multiple_choice
                         "Create #{count} multiple choice questions with 4 options each (A, B, C, D) and indicate the correct answer."
                       when :short_answer
                         "Create #{count} short answer questions that require 2-3 sentence responses."
                       when :true_false
                         "Create #{count} true/false questions with explanations."
                       when :mixed
                         "Create #{count} mixed questions including multiple choice, true/false, and short answer."
                       end

    <<~PROMPT
      Based on the following text, #{type_instruction}
      
      Format your response as a JSON array with this structure:
      [
        {
          "type": "multiple_choice|short_answer|true_false",
          "question": "Question text",
          "options": ["A", "B", "C", "D"] (for multiple choice only),
          "correct_answer": "A" or "True/False" or "Short answer explanation",
          "explanation": "Why this is correct"
        }
      ]

      Text:
      #{text}
    PROMPT
  end

  def parse_questions(content, question_type)
    # Try to parse JSON from the response
    json_match = content.match(/\[.*\]/m)
    return [] unless json_match

    questions = JSON.parse(json_match[0])
    questions.map do |q|
      {
        type: q["type"],
        question: q["question"],
        options: q["options"],
        correct_answer: q["correct_answer"],
        explanation: q["explanation"]
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse questions JSON: #{e.message}")
    []
  end

  def token_limit_for_length(length)
    case length
    when :short then 150
    when :medium then 300
    when :long then 600
    else 300
    end
  end

  def success_response(data)
    { success: true, data: data, error: nil }
  end

  def error_response(message)
    { success: false, data: nil, error: message }
  end

  # Mock AI responses for testing/development without API calls
  def mock_summarize(text, length)
    sleep(rand(1.0..2.5)) # Simulate API delay
    
    case length
    when :short
      "This is a brief summary of the provided text. Key points have been extracted and condensed."
    when :medium
      "This is a comprehensive summary of your text. The main ideas have been identified and presented clearly. Important concepts are highlighted, and the overall message is preserved while reducing length significantly."
    when :long
      "This is a detailed summary of your content. The text has been analyzed carefully to extract all key points and main themes. Important concepts are explained thoroughly, supporting details are included where relevant, and the overall narrative flow is maintained. This summary provides a complete overview while still being more concise than the original."
    else
      "This is a mock summary of your text. In production, this would be generated by OpenAI's GPT model."
    end
  end

  def mock_generate_questions(text, question_type, count)
    sleep(rand(2.0..4.0)) # Simulate API delay
    
    questions = []
    count.times do |i|
      case question_type
      when :multiple_choice
        options = [
          "The foundational principles and core concepts", 
          "Advanced implementation strategies",
          "Historical context and background",
          "Practical applications and use cases"
        ]
        questions << {
          type: 'multiple_choice',
          question: "What is the main concept discussed in point #{i + 1} of the text?",
          options: options,
          correct_answer: options[1], # "Advanced implementation strategies"
          explanation: "This is a mock explanation. The text emphasizes advanced strategies based on the analysis."
        }
      when :true_false
        questions << {
          type: 'true_false',
          question: "Statement #{i + 1}: The text discusses important educational concepts.",
          options: ['True', 'False'],
          correct_answer: 'True',
          explanation: "This statement is true based on the content provided."
        }
      when :short_answer
        questions << {
          type: 'short_answer',
          question: "Explain the key concept #{i + 1} mentioned in the text.",
          options: [],
          correct_answer: "A comprehensive explanation would include multiple aspects of the concept, considering both theoretical foundations and practical applications.",
          explanation: "Look for specific details in the text that support your answer."
        }
      else
        # Mixed questions - randomly choose a type
        type = [:multiple_choice, :true_false, :short_answer].sample
        questions << mock_generate_questions(text, type, 1).first
      end
    end
    
    questions
  end

  def mock_study_hints(topic)
    sleep(rand(0.5..1.5)) # Simulate API delay
    
    [
      "Start by breaking down #{topic} into smaller, manageable concepts",
      "Create a mind map or visual diagram to connect related ideas",
      "Practice explaining the concept in your own words",
      "Find real-world examples that demonstrate the principles",
      "Test your understanding by teaching the concept to someone else"
    ]
  end

  # Simple in-memory rate limiter with better tracking
  class RateLimiter
    attr_reader :limit, :window
    
    def initialize(limit, window)
      @limit = limit
      @window = window
      @requests = []
      @mutex = Mutex.new
    end

    def allow_request?
      @mutex.synchronize do
        cleanup_old_requests
        
        if @requests.size < @limit
          @requests << Time.current
          true
        else
          false
        end
      end
    end

    def remaining_requests
      @mutex.synchronize do
        cleanup_old_requests
        @limit - @requests.size
      end
    end

    def can_make_request?
      @mutex.synchronize do
        cleanup_old_requests
        @requests.size < @limit
      end
    end

    def reset_time
      @mutex.synchronize do
        cleanup_old_requests
        return Time.current if @requests.empty?
        
        # Return when the oldest request will expire
        @requests.first + @window.seconds
      end
    end

    private

    def cleanup_old_requests
      cutoff_time = Time.current - @window.seconds
      @requests.reject! { |time| time < cutoff_time }
    end
  end

  class RateLimitExceededError < StandardError; end
end
