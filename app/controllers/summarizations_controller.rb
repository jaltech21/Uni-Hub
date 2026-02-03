class SummarizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_rate_limit_info
  layout 'dashboard'

  # GET /summarizations/new
  def new
    @text = params[:text] || session[:summarization_text]
    @summary = session[:summarization_result]
    session.delete(:summarization_text)
    session.delete(:summarization_result)
  end

  # POST /summarizations
  def create
    @text = params[:text]
    length = params[:length]&.to_sym || :medium

    # Validation
    if @text.blank?
      flash.now[:alert] = "Please enter some text to summarize"
      render :new, status: :unprocessable_entity
      return
    end

    if @text.length < 100
      flash.now[:alert] = "Text must be at least 100 characters long (currently #{@text.length} characters)"
      render :new, status: :unprocessable_entity
      return
    end

    # Check if OpenAI is configured
    unless openai_configured?
      flash.now[:alert] = "AI features are not currently available. Please contact support."
      render :new, status: :service_unavailable
      return
    end

    Rails.logger.info("Summarization request - User: #{current_user.id}, Length: #{length}, Text length: #{@text.length}")

    # Call AI service
    result = AiServiceFactory.provider.summarize_text(@text, length: length, user_id: current_user.id)

    if result[:success]
      @summary = result[:summary]
      @word_count = @text.split.size
      @summary_word_count = @summary.split.size
      @compression_ratio = ((@summary_word_count.to_f / @word_count) * 100).round(1)
      
      Rails.logger.info("Summarization successful - User: #{current_user.id}, Original: #{@word_count} words, Summary: #{@summary_word_count} words")
      flash.now[:notice] = "✨ Summary generated successfully! Compressed from #{@word_count} to #{@summary_word_count} words."
      render :new
    elsif result[:rate_limited]
      Rails.logger.warn("Rate limit hit - User: #{current_user.id}")
      flash.now[:alert] = result[:error]
      render :new, status: :too_many_requests
    else
      Rails.logger.warn("Summarization failed - User: #{current_user.id}, Error: #{result[:error]}")
      flash.now[:alert] = result[:error]
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Unexpected summarization error - User: #{current_user.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    flash.now[:alert] = "An unexpected error occurred. Please try again or contact support if the issue persists."
    render :new, status: :internal_server_error
  end

  # POST /summarizations/save_to_note
  def save_to_note
    title = params[:title]
    summary = params[:summary]
    original_text = params[:original_text]

    if title.blank? || summary.blank?
      redirect_to new_summarization_path, alert: "Cannot save empty summary. Please generate a summary first."
      return
    end

    Rails.logger.info("Saving summary to note - User: #{current_user.id}, Title: #{title}")

    # Create note with summary
    note_content = "## Summary\n\n#{summary}"
    
    if params[:include_original] == "1" && original_text.present?
      note_content += "\n\n---\n\n## Original Text\n\n#{original_text}"
    end

    note = current_user.notes.build(
      title: title,
      content: note_content
    )

    if note.save
      Rails.logger.info("Summary saved successfully - User: #{current_user.id}, Note: #{note.id}")
      redirect_to note_path(note), notice: "📝 Summary saved to notes successfully!"
    else
      Rails.logger.error("Failed to save summary - User: #{current_user.id}, Errors: #{note.errors.full_messages.join(', ')}")
      session[:summarization_text] = original_text
      session[:summarization_result] = summary
      redirect_to new_summarization_path, alert: "Failed to save note: #{note.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error("Error saving summary to note - User: #{current_user.id}: #{e.message}")
    redirect_to new_summarization_path, alert: "An error occurred while saving. Please try again."
  end

  private

  def set_rate_limit_info
    provider = AiServiceFactory.provider
    @rate_limit_max = provider.max_requests_per_hour
    @rate_limit_remaining = provider.remaining_requests(current_user.id)
  end

  def openai_configured?
    api_key = Rails.application.config.openai_api_key || 
              Rails.application.credentials.dig(:openai, :api_key) || 
              ENV['OPENAI_API_KEY']
    api_key.present?
  end
end
