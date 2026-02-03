# frozen_string_literal: true

# OpenAI Configuration
# Set your API key in credentials or environment variable
# 
# For development:
#   export OPENAI_API_KEY=your_key_here
#
# For production, use Rails credentials:
#   rails credentials:edit
#   Add: openai: { api_key: your_key_here }

# Configure OpenAI gem with API key from credentials or environment variable
# The 'openai' gem (v0.28.0) uses OpenAI::Client initialized with access_token
# No global configuration method like ruby-openai gem

api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']

if api_key.present?
  # Store the API key for use by OpenAiService
  Rails.application.config.openai_api_key = api_key
  
  Rails.logger.info "✅ OpenAI configured successfully"
else
  Rails.logger.warn "⚠️  OpenAI API key is not configured. Set OPENAI_API_KEY environment variable or add to credentials."
  Rails.logger.warn "   For development: export OPENAI_API_KEY=sk-your-key"
  Rails.logger.warn "   For production: rails credentials:edit and add openai: { api_key: sk-your-key }"
end
