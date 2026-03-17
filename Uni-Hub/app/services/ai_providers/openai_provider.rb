# frozen_string_literal: true

module AiProviders
  class OpenaiProvider < BaseProvider
    OPENAI_MODEL = 'gpt-3.5-turbo'
    
    def initialize(api_key: ENV['OPENAI_API_KEY'])
      super(api_key: api_key)
      OpenAI.configure do |config|
        config.access_token = @api_key
      end
      @client = OpenAI::Client.new
    end

    def summarize_text(text, length:, user_id:)
      start_time = Time.current
      
      # Check rate limit
      unless can_make_request?(user_id)
        log_rate_limit(user_id, 'summarize_text')
        return {
          success: false,
          error: "Rate limit exceeded. Please wait before making another request.",
          rate_limited: true
        }
      end

      begin
        log_request(user_id, 'summarize_text', { length: length, text_length: text.length })
        
        prompt = build_summary_prompt(text, length)
        
        response = @client.chat(
          parameters: {
            model: OPENAI_MODEL,
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.7
          }
        )
        
        summary = response.dig('choices', 0, 'message', 'content')
        tokens_used = response.dig('usage', 'total_tokens')
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'summarize_text', processing_time, tokens_used)
        
        {
          success: true,
          summary: summary,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue OpenAI::Error => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'summarize_text', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'summarize_text', e, processing_time)
        
        {
          success: false,
          error: "Unexpected error: #{e.message}"
        }
      end
    end

    def generate_questions(text, question_type:, count:, difficulty:, user_id:)
      start_time = Time.current
      
      # Check rate limit
      unless can_make_request?(user_id)
        log_rate_limit(user_id, 'generate_questions')
        return {
          success: false,
          error: "Rate limit exceeded. Please wait before making another request.",
          rate_limited: true
        }
      end

      begin
        log_request(user_id, 'generate_questions', { 
          question_type: question_type, 
          count: count, 
          difficulty: difficulty 
        })
        
        prompt = build_questions_prompt(text, question_type, count, difficulty)
        
        response = @client.chat(
          parameters: {
            model: OPENAI_MODEL,
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.8
          }
        )
        
        response_text = response.dig('choices', 0, 'message', 'content')
        questions = parse_questions_response(response_text)
        tokens_used = response.dig('usage', 'total_tokens')
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'generate_questions', processing_time, tokens_used)
        
        {
          success: true,
          questions: questions,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue OpenAI::Error => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'generate_questions', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'generate_questions', e, processing_time)
        
        {
          success: false,
          error: "Unexpected error: #{e.message}"
        }
      end
    end

    def get_study_hints(topic, user_id:)
      start_time = Time.current
      
      # Check rate limit
      unless can_make_request?(user_id)
        log_rate_limit(user_id, 'get_study_hints')
        return {
          success: false,
          error: "Rate limit exceeded. Please wait before making another request.",
          rate_limited: true
        }
      end

      begin
        log_request(user_id, 'get_study_hints', { topic: topic })
        
        prompt = build_hints_prompt(topic)
        
        response = @client.chat(
          parameters: {
            model: OPENAI_MODEL,
            messages: [{ role: 'user', content: prompt }],
            temperature: 0.7
          }
        )
        
        response_text = response.dig('choices', 0, 'message', 'content')
        hints = parse_hints_response(response_text)
        tokens_used = response.dig('usage', 'total_tokens')
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'get_study_hints', processing_time, tokens_used)
        
        {
          success: true,
          hints: hints,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue OpenAI::Error => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'get_study_hints', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'get_study_hints', e, processing_time)
        
        {
          success: false,
          error: "Unexpected error: #{e.message}"
        }
      end
    end

    private

    def build_summary_prompt(text, length)
      length_instruction = case length
      when :short then "Provide a brief, concise summary (2-3 sentences)."
      when :medium then "Provide a comprehensive summary (1 paragraph, 5-7 sentences)."
      when :long then "Provide a detailed summary (2-3 paragraphs) covering all key points."
      else "Provide a clear summary of the text."
      end

      <<~PROMPT
        You are an expert educational assistant helping students understand their study materials.
        
        #{length_instruction}
        
        Focus on:
        - Main ideas and key concepts
        - Important details and supporting evidence
        - Clear, student-friendly language
        
        Text to summarize:
        #{text}
        
        Summary:
      PROMPT
    end

    def build_questions_prompt(text, question_type, count, difficulty)
      type_instruction = case question_type.to_sym
      when :multiple_choice
        "Generate #{count} multiple choice questions. Each question must have exactly 4 options."
      when :true_false
        "Generate #{count} true/false questions."
      when :short_answer
        "Generate #{count} short answer questions that require students to explain concepts."
      else
        "Generate #{count} mixed-type questions (multiple choice, true/false, and short answer)."
      end

      difficulty_instruction = case difficulty.to_sym
      when :easy then "Questions should test basic recall and understanding."
      when :medium then "Questions should test application and analysis."
      when :hard then "Questions should test synthesis and evaluation."
      else "Questions should be appropriately challenging."
      end

      <<~PROMPT
        You are an expert educational assistant creating quiz questions for students.
        
        #{type_instruction}
        #{difficulty_instruction}
        
        Based on this text:
        #{text}
        
        Format your response as a JSON array where each question is an object with these fields:
        - type: "multiple_choice", "true_false", or "short_answer"
        - question: the question text
        - options: array of answer choices (4 for multiple choice, ["True", "False"] for true/false, empty array for short answer)
        - correct_answer: the correct answer (must exactly match one of the options)
        - explanation: brief explanation of why this is the correct answer
        
        Return ONLY the JSON array, no additional text.
      PROMPT
    end

    def build_hints_prompt(topic)
      <<~PROMPT
        You are an expert educational assistant helping students study effectively.
        
        Provide 5 practical, actionable study hints for learning about: #{topic}
        
        Focus on:
        - Effective study techniques
        - Memory and retention strategies
        - Practical learning approaches
        - Active learning methods
        
        Format your response as a numbered list (1-5).
      PROMPT
    end

    def parse_questions_response(response_text)
      json_match = response_text.match(/```json\s*(\[.*?\])\s*```/m) || 
                   response_text.match(/(\[.*?\])/m)
      
      if json_match
        questions_data = JSON.parse(json_match[1])
        questions_data.map do |q|
          {
            type: q['type'],
            question: q['question'],
            options: q['options'] || [],
            correct_answer: q['correct_answer'],
            explanation: q['explanation']
          }
        end
      else
        raise "Failed to parse questions from OpenAI response"
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse OpenAI questions JSON: #{e.message}"
      raise "Invalid JSON response from OpenAI API"
    end

    def parse_hints_response(response_text)
      hints = response_text.scan(/^\d+\.\s*(.+?)(?=\n\d+\.|$)/m).flatten
      
      if hints.empty?
        hints = response_text.split("\n")
                            .map(&:strip)
                            .reject(&:empty?)
                            .first(5)
      end
      
      hints.map { |h| h.gsub(/^\d+\.\s*/, '').strip }
    end

    def format_error_message(error)
      case error
      when OpenAI::Errors::AuthenticationError
        "⚠️ OpenAI API authentication failed. Please check your API key."
      when OpenAI::Errors::RateLimitError
        "⚠️ OpenAI API quota exceeded. Your API key has run out of credits. Please add credits at https://platform.openai.com/account/billing"
      when OpenAI::Errors::QuotaExceededError
        "⚠️ OpenAI API quota exceeded. Please check your usage limits."
      when OpenAI::Errors::APIConnectionError
        "⚠️ Could not connect to OpenAI API. Please check your internet connection."
      else
        "⚠️ OpenAI API error: #{error.message}"
      end
    end
  end
end
