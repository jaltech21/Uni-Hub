# frozen_string_literal: true

require 'gemini-ai'

module AiProviders
  class GeminiProvider < BaseProvider
    GEMINI_MODEL = 'gemini-2.5-flash-preview-05-20'
    
    def initialize(api_key: ENV['GEMINI_API_KEY'])
      super(api_key: api_key)
      @client = Gemini.new(
        credentials: {
          service: 'generative-language-api',
          api_key: @api_key,
          version: 'v1beta'
        },
        options: {
          model: GEMINI_MODEL,
          server_sent_events: false
        }
      )
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
        response = @client.generate_content({ contents: { role: 'user', parts: { text: prompt } } })
        
        summary = extract_text_from_response(response)
        tokens_used = estimate_tokens(prompt, summary)
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'summarize_text', processing_time, tokens_used)
        
        {
          success: true,
          summary: summary,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'summarize_text', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
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
        response = @client.generate_content({ 
          contents: { role: 'user', parts: { text: prompt } },
          generationConfig: {
            temperature: 0.4,  # Lower temperature for more consistent JSON
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 2048  # Allow longer responses
          }
        })
        
        response_text = extract_text_from_response(response)
        questions = parse_questions_response(response_text, question_type)
        tokens_used = estimate_tokens(prompt, response_text)
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'generate_questions', processing_time, tokens_used)
        
        {
          success: true,
          questions: questions,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'generate_questions', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
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
        response = @client.generate_content({ contents: { role: 'user', parts: { text: prompt } } })
        
        response_text = extract_text_from_response(response)
        hints = parse_hints_response(response_text)
        tokens_used = estimate_tokens(prompt, response_text)
        
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'get_study_hints', processing_time, tokens_used)
        
        {
          success: true,
          hints: hints,
          tokens_used: tokens_used,
          processing_time: processing_time
        }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'get_study_hints', e, processing_time)
        
        {
          success: false,
          error: format_error_message(e)
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
        "Generate #{count} multiple choice questions. Each question must have exactly 4 options and 1 correct answer."
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
        Create #{count} #{question_type} quiz questions about this text. #{difficulty_instruction}
        
        Text:
        #{text[0..1500]}
        
        CRITICAL: correct_answer MUST be the EXACT FULL TEXT of one of the options, not a letter code.
        
        Return ONLY a JSON array with NO markdown formatting:
        [{"type":"#{question_type}","question":"Question text here?","options":["First option text","Second option text","Third option text","Fourth option text"],"correct_answer":"Second option text","explanation":"Because..."}]
        
        Your complete JSON array:
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
        
        Format your response as a numbered list (1-5), with each hint on a new line.
        Keep each hint concise (1-2 sentences).
      PROMPT
    end

    def extract_text_from_response(response)
      # Extract text from non-streaming response
      if response.is_a?(Hash) && response.dig('candidates', 0, 'content', 'parts')
        candidate = response['candidates'][0]
        parts = candidate['content']['parts']
        text = parts.map { |part| part['text'] }.join('')
        
        # Log finish reason for debugging
        finish_reason = candidate['finishReason']
        if finish_reason && finish_reason != 'STOP'
          Rails.logger.warn "Gemini generation finished with reason: #{finish_reason}"
        end
        
        text
      else
        # Fallback for different response format
        response.to_s
      end
    end

    def parse_questions_response(response_text, question_type)
      # Clean the response text
      cleaned_text = response_text.strip
      
      # Log the response for debugging
      Rails.logger.info "Gemini response length: #{cleaned_text.length} characters"
      
      # Try multiple JSON extraction patterns - GREEDY matching to get complete JSON
      json_match = cleaned_text.match(/```json\s*(\[.*\])\s*```/m) || 
                   cleaned_text.match(/```\s*(\[.*\])\s*```/m) ||
                   cleaned_text.match(/(\[.*\])/m)
      
      if json_match
        json_string = json_match[1].strip
        Rails.logger.info "Extracted JSON string length: #{json_string.length}"
        
        # Clean up potential issues in JSON string
        json_string = json_string.gsub(/\n\s*\n/, "\n")  # Remove double newlines
        
        questions_data = JSON.parse(json_string)
        
        unless questions_data.is_a?(Array)
          raise "Expected array but got #{questions_data.class}"
        end
        
        # Convert to expected format and validate
        questions_data.map do |q|
          {
            type: q['type'],
            question: q['question'],
            options: q['options'] || [],
            correct_answer: q['correct_answer'],
            explanation: q['explanation'] || 'No explanation provided'
          }
        end
      else
        # If no JSON markers found, try parsing the whole response as JSON
        begin
          questions_data = JSON.parse(cleaned_text)
          if questions_data.is_a?(Array)
            return questions_data.map do |q|
              {
                type: q['type'],
                question: q['question'],
                options: q['options'] || [],
                correct_answer: q['correct_answer'],
                explanation: q['explanation'] || 'No explanation provided'
              }
            end
          end
        rescue JSON::ParserError
          # Fall through to error handling
        end
        
        Rails.logger.error "No JSON array found in Gemini response"
        Rails.logger.error "Response text (first 500 chars): #{cleaned_text[0..500]}"
        raise "Failed to parse questions from Gemini response - no JSON array found"
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Gemini questions JSON: #{e.message}"
      Rails.logger.error "JSON string that failed: #{json_string[0..200] rescue 'N/A'}"
      Rails.logger.error "Full response (first 1000 chars): #{cleaned_text[0..1000]}"
      raise "Invalid JSON response from Gemini API: #{e.message}"
    end

    def parse_hints_response(response_text)
      # Extract hints from numbered list
      hints = response_text.scan(/^\d+\.\s*(.+?)(?=\n\d+\.|$)/m).flatten
      
      # If no numbered list found, split by newlines and filter
      if hints.empty?
        hints = response_text.split("\n")
                            .map(&:strip)
                            .reject(&:empty?)
                            .first(5)
      end
      
      hints.map { |h| h.gsub(/^\d+\.\s*/, '').strip }
    end

    def estimate_tokens(prompt, response)
      # Rough estimation: 1 token ≈ 4 characters
      ((prompt.length + response.length) / 4.0).ceil
    end

    def format_error_message(error)
      case error.message
      when /API key/i
        "⚠️ Gemini API key error. Please check your GEMINI_API_KEY environment variable."
      when /quota|limit/i
        "⚠️ Gemini API quota exceeded. Please try again later or check your usage limits."
      when /network|connection|timeout/i
        "⚠️ Network error connecting to Gemini API. Please check your internet connection."
      else
        "⚠️ Gemini API error: #{error.message}"
      end
    end
  end
end
