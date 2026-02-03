# frozen_string_literal: true

class AiServiceFactory
  include Singleton

  PROVIDERS = {
    'gemini' => 'AiProviders::GeminiProvider',
    'openai' => 'AiProviders::OpenaiProvider',
    'mock' => 'AiProviders::MockProvider'
  }.freeze

  def self.provider
    instance.provider
  end

  def provider
    @provider ||= initialize_provider
  end

  def reset!
    @provider = nil
  end

  private

  def initialize_provider
    provider_name = ENV['AI_PROVIDER']&.downcase || 'gemini'
    
    unless PROVIDERS.key?(provider_name)
      Rails.logger.warn "Unknown AI provider '#{provider_name}', falling back to mock"
      provider_name = 'mock'
    end

    provider_class = PROVIDERS[provider_name].constantize
    
    Rails.logger.info "Initializing AI provider: #{provider_name}"
    
    case provider_name
    when 'gemini'
      validate_api_key!('GEMINI_API_KEY')
      provider_class.new(api_key: ENV['GEMINI_API_KEY'])
    when 'openai'
      validate_api_key!('OPENAI_API_KEY')
      provider_class.new(api_key: ENV['OPENAI_API_KEY'])
    when 'mock'
      provider_class.new
    end
  rescue StandardError => e
    Rails.logger.error "Failed to initialize AI provider '#{provider_name}': #{e.message}"
    Rails.logger.warn "Falling back to mock provider"
    AiProviders::MockProvider.new
  end

  def validate_api_key!(env_var_name)
    api_key = ENV[env_var_name]
    
    if api_key.blank?
      raise "#{env_var_name} is not set. Please set it in your .env file or use AI_PROVIDER=mock"
    end
    
    if api_key.length < 20
      raise "#{env_var_name} appears to be invalid (too short). Please check your .env file"
    end
  end
end
