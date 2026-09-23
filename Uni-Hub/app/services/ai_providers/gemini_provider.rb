# frozen_string_literal: true

require 'gemini-ai'
require 'timeout'

module AiProviders
  class GeminiProvider < BaseProvider
    GEMINI_MODEL = ENV.fetch('GEMINI_MODEL', 'gemini-3.6-flash').freeze

    # Free-tier Gemini keys are limited to a low number of requests per minute
    # (RPM). We throttle just below that so bursts of UI actions don't trip the
    # provider's 429 window, and we retry transparently when the service still
    # returns 429.
    MAX_REQUESTS_PER_MINUTE = ENV.fetch('GEMINI_MAX_REQUESTS_PER_MINUTE', 15).to_i
    MAX_429_RETRIES = ENV.fetch('GEMINI_MAX_429_RETRIES', 3).to_i
    MAX_THROTTLE_WAIT = ENV.fetch('GEMINI_MAX_THROTTLE_WAIT', 90).to_i

    class RateLimitedError < StandardError; end

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
      @throttle_mutex = Mutex.new
      @request_times = []
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
        response = generate_content(prompt)
        
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
          error: format_error_message(e),
          rate_limited: rate_limited_error?(e)
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
        response = generate_content(prompt, generation_config: {
          temperature: 0.4,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 2048
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
          error: format_error_message(e),
          rate_limited: rate_limited_error?(e)
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
        response = generate_content(prompt)
        
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
          error: format_error_message(e),
          rate_limited: rate_limited_error?(e)
        }
      end
    end

    def answer_prompt(prompt, user_id:)
      start_time = Time.current
      unless can_make_request?(user_id)
        log_rate_limit(user_id, 'answer_prompt')
        return { success: false, error: "Rate limit exceeded. Please wait before making another request.", rate_limited: true }
      end

      begin
        log_request(user_id, 'answer_prompt', { prompt_length: prompt.length })
        instruction = <<~PROMPT
          You are UniHub AI, a capable conversational generative AI assistant for a university student.
          Interpret the student's exact request before answering. Do not turn every request into a
          generic study-plan paragraph. Respond to the requested task itself:
          - For a study plan, create a concrete day-by-day or session-by-session plan with realistic durations.
          - For an explanation, teach the concept step by step with an example and a quick check question.
          - For an exam request, create useful questions, answers, and explanations from the supplied material.
          - For a schedule request, use the supplied schedule and clearly identify dates, times, and conflicts.
          - For progress questions, cite the supplied metrics and distinguish facts from recommendations.
          - For any other prompt, answer naturally like a general-purpose Gemini-style assistant.
          Use concise headings, bullets, tables, or numbered steps when they improve clarity. Ask one
          focused follow-up question only when essential information is missing. Never invent student
          data, grades, deadlines, or schedule entries.

          Student request and private application context:
          #{prompt}

          Answer the request now:
        PROMPT
        response_text = extract_text_from_response(generate_content(instruction))
        tokens_used = estimate_tokens(instruction, response_text)
        @rate_limiter.record_request(user_id)
        processing_time = (Time.current - start_time).round(2)
        log_success(user_id, 'answer_prompt', processing_time, tokens_used)
        { success: true, summary: response_text, tokens_used: tokens_used, processing_time: processing_time }
      rescue StandardError => e
        processing_time = (Time.current - start_time).round(2)
        log_failure(user_id, 'answer_prompt', e, processing_time)
        { success: false, error: format_error_message(e), rate_limited: rate_limited_error?(e) }
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
      requested = question_type.to_sym
      type_instruction = case requested
      when :multiple_choice
        "Generate #{count} multiple choice questions. Each question must have exactly 4 options and 1 correct answer."
      when :true_false
        "Generate #{count} true/false questions."
      when :short_answer
        "Generate #{count} short answer questions that require students to explain concepts."
      else
        "Generate #{count} mixed-type questions (multiple choice, true/false, and short answer)."
      end

      allowed = %w[multiple_choice true_false short_answer]
      type_fix = if requested == :mixed
                   "Each question's \"type\" MUST be one of: #{allowed.join(', ')}."
                 else
                   "Each question's \"type\" MUST be exactly \"#{question_type}\"."
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
        #{type_fix}
        
        Return ONLY a JSON array with NO markdown formatting:
        [{"type":"multiple_choice","question":"Question text here?","options":["First option text","Second option text","Third option text","Fourth option text"],"correct_answer":"Second option text","explanation":"Because..."}]
        
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

    def generate_content(prompt, generation_config: nil)
      # gemini-3.6-flash reasons by default; disable reasoning-mode "thinking"
      # so responses return in ~2s instead of ~6s+ unless a caller opts in.
      config = (generation_config || {}).merge(thinkingConfig: { thinkingBudget: 0 })
      request = { contents: { role: 'user', parts: { text: prompt } } }
      request[:generationConfig] = config unless config.empty?

      wait_for_rate_slot!
      attempt = 0
      begin
        Timeout.timeout(30) { @client.generate_content(request) }
      rescue Faraday::TooManyRequestsError => e
        attempt += 1
        raise if attempt >= MAX_429_RETRIES

        delay = retry_delay(e, attempt)
        Rails.logger.warn "Gemini 429 (rate limited). Retrying in #{delay}s (attempt #{attempt + 1}/#{MAX_429_RETRIES})"
        sleep(delay)
        retry
      rescue Faraday::ServerError, Faraday::ConnectionFailed, Faraday::TimeoutError => e
        attempt += 1
        raise if attempt >= MAX_429_RETRIES

        delay = (2**attempt) + rand(0..1)
        Rails.logger.warn "Gemini transport error (#{e.class}). Retrying in #{delay}s (attempt #{attempt + 1}/#{MAX_429_RETRIES})"
        sleep(delay)
        retry
      end
    rescue Timeout::Error
      raise "Gemini API request timed out. Please try again."
    end

    # Holds the request until there is room in this process' sliding 60s window,
    # so bursts of UI actions stay under the provider's free-tier RPM cap.
    def wait_for_rate_slot!
      deadline = Time.current + MAX_THROTTLE_WAIT.seconds
      loop do
        delay = @throttle_mutex.synchronize do
          cutoff = 60.seconds.ago
          @request_times.reject! { |t| t < cutoff }
          if @request_times.size < MAX_REQUESTS_PER_MINUTE
            @request_times << Time.current
            nil
          else
            @request_times.first - cutoff
          end
        end
        return if delay.nil?

        remaining = deadline - Time.current
        raise RateLimitedError, "Gemini rate limit reached. Please wait a moment before trying again." if remaining <= 0
        sleep([delay, 5].min)
      end
    end

    # Uses the server-provided retry time when available (e.g. "retry in 22.7s"),
    # otherwise falls back to exponential backoff.
    def retry_delay(error, attempt)
      body = error.respond_to?(:response) ? error.response.to_h[:body].to_s : error.to_s
      match = body.match(/retry in ([\d.]+)s?/i)
      return (match[1].to_f + 0.5).ceil if match

      (2**attempt) + rand(0..1)
    end
    def extract_text_from_response(response)
      payload = response.respond_to?(:to_h) ? response.to_h : response
      candidates = payload['candidates'] || payload[:candidates]
      candidate = candidates.is_a?(Array) ? candidates.first : nil
      content = candidate && (candidate['content'] || candidate[:content])
      parts = content && (content['parts'] || content[:parts])

      unless parts.is_a?(Array)
        raise 'Gemini returned an invalid or empty response.'
      end

      text = parts.map { |part| part['text'] || part[:text] }.compact.join.strip
      finish_reason = candidate['finishReason'] || candidate[:finishReason] if candidate
      if finish_reason && finish_reason != 'STOP'
        Rails.logger.warn "Gemini generation finished with reason: #{finish_reason}"
      end
      raise 'Gemini returned an empty response.' if text.empty?

      text
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
        questions_data.map { |q| normalize_question(q, question_type) }
      else
        # If no JSON markers found, try parsing the whole response as JSON
        begin
          questions_data = JSON.parse(cleaned_text)
          if questions_data.is_a?(Array)
            return questions_data.map { |q| normalize_question(q, question_type) }
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

    def normalize_question(q, question_type)
      allowed = %w[multiple_choice true_false short_answer]
      raw_type = q['type'].to_s.strip
      type = if question_type.to_sym == :mixed
               allowed.include?(raw_type) ? raw_type : infer_question_type(q)
             else
               question_type.to_s
             end

      {
        type: type,
        question: q['question'],
        options: q['options'] || [],
        correct_answer: q['correct_answer'],
        explanation: q['explanation'] || 'No explanation provided'
      }
    end

    def infer_question_type(q)
      options = q['options']
      if options.is_a?(Array) && options.length >= 2
        'multiple_choice'
      elsif q['question'].to_s =~ /\b(true|false)\b/i
        'true_false'
      else
        'short_answer'
      end
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
      if rate_limited_error?(error)
        return "⚠️ Gemini is currently rate-limited. Please wait a moment before trying again."
      end

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

    def rate_limited_error?(error)
      error.is_a?(Faraday::TooManyRequestsError) ||
        error.is_a?(RateLimitedError) ||
        error.message.to_s =~ /status 429|quota exceeded|RESOURCE_EXHAUSTED|rate limit/i
    end
  end
end
