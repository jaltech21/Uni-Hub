# frozen_string_literal: true

namespace :ai do
  desc "Check OpenAI API configuration and status"
  task check: :environment do
    service = OpenAiService.instance
    
    puts "\n" + "="*60
    puts "AI SERVICE STATUS CHECK"
    puts "="*60
    
    # Check mock mode
    if service.mock_mode
      puts "✅ Mode: MOCK MODE ENABLED"
      puts "   AI features will use simulated responses (no API calls)"
    else
      puts "✅ Mode: PRODUCTION MODE"
      puts "   AI features will call OpenAI API"
    end
    
    # Check API key
    api_key = ENV['OPENAI_API_KEY']
    if api_key.present?
      puts "✅ API Key: Configured (length: #{api_key.length})"
    else
      puts "❌ API Key: NOT CONFIGURED"
    end
    
    # Check client
    if service.client.present?
      puts "✅ Client: Initialized"
    else
      puts "⚠️  Client: Not initialized (running in mock mode)"
    end
    
    # Rate limiter info
    puts "\n📊 RATE LIMITER SETTINGS:"
    puts "   Limit: #{OpenAiService::RATE_LIMIT} requests per minute"
    puts "   Window: #{OpenAiService::RATE_WINDOW} seconds"
    
    puts "\n" + "="*60
    puts "To enable mock mode: export AI_MOCK_MODE=true"
    puts "To disable mock mode: unset AI_MOCK_MODE"
    puts "="*60 + "\n"
  end

  desc "Clear all rate limiters (reset request counts)"
  task clear_limiters: :environment do
    service = OpenAiService.instance
    rate_limiters = service.instance_variable_get(:@rate_limiters)
    count = rate_limiters.size
    rate_limiters.clear
    puts "✅ Cleared #{count} rate limiter(s)"
  end

  desc "Enable mock mode (add to .env or export in terminal)"
  task enable_mock: :environment do
    puts "\n" + "="*60
    puts "TO ENABLE MOCK MODE:"
    puts "="*60
    puts "\n1. For this session (terminal):"
    puts "   export AI_MOCK_MODE=true"
    puts "\n2. For persistent (add to .env file):"
    puts "   AI_MOCK_MODE=true"
    puts "\n3. Restart your Rails server"
    puts "\n" + "="*60 + "\n"
  end

  desc "Test AI service with mock data"
  task test: :environment do
    puts "\n" + "="*60
    puts "TESTING AI SERVICE"
    puts "="*60
    
    service = OpenAiService.instance
    user = User.first
    
    unless user
      puts "❌ No users found. Please create a user first."
      exit 1
    end
    
    puts "\n📝 Testing summarization..."
    result = service.summarize_text(
      "This is a test text for the summarization feature. " * 20,
      length: :short,
      user_id: user.id
    )
    
    if result[:success]
      puts "✅ Summarization successful!"
      puts "   Summary: #{result[:data][0..100]}..."
    else
      puts "❌ Summarization failed: #{result[:error]}"
    end
    
    puts "\n❓ Testing question generation..."
    result = service.generate_questions(
      "This is a test text for question generation. " * 50,
      question_type: :mixed,
      count: 3,
      user_id: user.id
    )
    
    if result[:success]
      puts "✅ Question generation successful!"
      puts "   Generated #{result[:data].size} questions"
    else
      puts "❌ Question generation failed: #{result[:error]}"
    end
    
    puts "\n" + "="*60 + "\n"
  end
end
