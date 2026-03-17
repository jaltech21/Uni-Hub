# OpenAI API Setup Guide

This guide will help you configure the OpenAI API key for the AI features in Uni-Hub.

## Prerequisites

1. You need an OpenAI account. Sign up at https://platform.openai.com/
2. Create an API key at https://platform.openai.com/api-keys

## Development Environment Setup

For local development, you can set the API key as an environment variable:

### Option 1: Using .env file (Recommended)

1. Install the dotenv-rails gem if not already installed:
```bash
bundle add dotenv-rails --group development, test
```

2. Create a `.env` file in the root directory:
```bash
touch .env
```

3. Add your API key to `.env`:
```
OPENAI_API_KEY=sk-your-api-key-here
```

4. Add `.env` to `.gitignore` to prevent committing your key:
```bash
echo ".env" >> .gitignore
```

5. Restart your Rails server

### Option 2: Export to Shell

Set the environment variable in your current shell session:

```bash
export OPENAI_API_KEY=sk-your-api-key-here
```

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) to make it permanent:

```bash
echo 'export OPENAI_API_KEY=sk-your-api-key-here' >> ~/.zshrc
source ~/.zshrc
```

## Production Environment Setup

For production (Heroku, AWS, etc.), use Rails encrypted credentials:

### Step 1: Edit credentials

```bash
EDITOR="nano" bin/rails credentials:edit
```

Or with VS Code:
```bash
EDITOR="code --wait" bin/rails credentials:edit
```

### Step 2: Add OpenAI configuration

Add the following to your credentials file:

```yaml
openai:
  api_key: sk-your-api-key-here
```

Save and close the editor.

### Step 3: Verify

Your credentials are encrypted in `config/credentials.yml.enc` and the key is in `config/master.key`. 

**Important:** 
- `config/credentials.yml.enc` - Commit this file (it's encrypted)
- `config/master.key` - **DO NOT** commit this file (add to .gitignore)

For production deployment, set the `RAILS_MASTER_KEY` environment variable with the contents of `config/master.key`.

## Testing the Configuration

### Check if API key is loaded

Start Rails console:
```bash
bin/rails console
```

Check if the service can access the key:
```ruby
OpenAiService.instance
```

You should see a success message if configured correctly.

### Test summarization

```ruby
# Test the summarization method
result = OpenAiService.instance.summarize_text(
  "Ruby on Rails is a web application framework written in Ruby. It is designed to make programming web applications easier by making assumptions about what every developer needs to get started. It allows you to write less code while accomplishing more than many other languages and frameworks.",
  length: :short
)

puts result[:success] ? result[:data] : result[:error]
```

### Test in the browser

1. Start the Rails server:
```bash
bin/rails server
```

2. Navigate to: http://localhost:3000/summarizations/new

3. Paste some text (minimum 100 characters)

4. Click "Generate Summary"

## API Usage and Costs

### Pricing (as of 2024)
- **GPT-3.5-turbo**: ~$0.002 per 1,000 tokens
- Input and output tokens are billed separately

### Rate Limiting
The application has built-in rate limiting:
- **10 requests per minute** per IP address
- Prevents excessive API usage and costs

### Token Estimation
- **Short summary**: ~150 tokens
- **Medium summary**: ~300 tokens  
- **Long summary**: ~600 tokens

For 1,000 summarizations (medium length):
- Approximate cost: $0.60 - $1.00

### Monitor Usage
Check your usage at: https://platform.openai.com/usage

## Troubleshooting

### "OpenAI API key is not configured"
- Make sure you've set the `OPENAI_API_KEY` environment variable
- Restart your Rails server after setting the variable
- Check that the key starts with `sk-`

### "Rate limit exceeded"
- Wait 1 minute before trying again
- The app limits requests to prevent excessive API usage

### "Invalid API key"
- Verify your API key is correct
- Check if the key has been revoked at https://platform.openai.com/api-keys
- Generate a new key if needed

### "Network error" or "Timeout"
- Check your internet connection
- OpenAI API might be experiencing downtime (check https://status.openai.com)
- Try again in a few moments

## Security Best Practices

1. **Never commit API keys to version control**
2. **Use environment variables** for development
3. **Use encrypted credentials** for production
4. **Rotate keys periodically** for security
5. **Monitor API usage** to detect unauthorized access
6. **Set usage limits** in OpenAI dashboard to prevent unexpected charges

## Features Using OpenAI API

### Current Features
- ✅ Text Summarization (adjustable length)

### Upcoming Features  
- ⏳ AI Exam Preparation (question generation)
- ⏳ Study Hints Generator
- ⏳ Note Enhancements

## Support

For issues with:
- **OpenAI API**: https://help.openai.com/
- **Uni-Hub Implementation**: Check application logs or contact support

---

Last updated: January 2025
