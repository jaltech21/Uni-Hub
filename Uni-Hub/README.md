# Uni-Hub

> A modern, AI-powered platform for university students to manage notes, assignments, and collaborative study.

## 🚀 Features

- 📝 **Smart Note-Taking**: Rich text editor with folders and tags
- 🤖 **AI-Powered Tools**: Text summarization, quiz generation, and study hints
- 📚 **Assignment Management**: Track deadlines and priorities
- 🔗 **Collaboration**: Share notes with classmates
- 📱 **Responsive Design**: Works on desktop, tablet, and mobile

## 🛠️ Tech Stack

- **Ruby**: 3.3.6
- **Rails**: 8.0.3
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS v4.1.13
- **JavaScript**: Vanilla JS + Hotwire (Turbo & Stimulus)
- **AI**: Google Gemini API (configurable provider with OpenAI/mock alternatives)
- **Authentication**: Devise 4.9.4

## 📋 Prerequisites

- Ruby 3.3.6 or higher
- Rails 8.0 or higher
- PostgreSQL
- Node.js (for JavaScript dependencies)
- Gemini API key (for AI features); OpenAI remains available as an alternative provider

## 🔧 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/uni-hub.git
   cd uni-hub/Uni-Hub
   ```

2. **Install dependencies:**
   ```bash
   bundle install
   ```

3. **Setup database:**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Configure the AI provider (Required for AI features):**
   
   Gemini is the default provider. Add these values to `.env` and restart Rails:
   ```bash
   AI_PROVIDER=gemini
   GEMINI_API_KEY=your-gemini-key
   GEMINI_MODEL=gemini-3.6-flash
   ```
   OpenAI can be selected with `AI_PROVIDER=openai`; use `OPENAI_API_KEY` for that provider.

5. **Start the server:**
   ```bash
   bin/dev
   # Or
   rails server
   ```

6. **Visit the application:**
   ```
   http://localhost:3000
   ```

## ⚙️ Configuration

### AI Provider (Required for AI Features)

The API supports summarization, quiz generation, study plans, and study hints through the provider selected by `AI_PROVIDER`.
The default is Gemini:

```bash
AI_PROVIDER=gemini
GEMINI_API_KEY=your-gemini-key
GEMINI_MODEL=gemini-3.6-flash
```

Restart Rails after changing provider settings. Verify the selected configuration with:
```bash
rails runner 'puts "AI provider: #{ENV.fetch(%q(AI_PROVIDER), %q(gemini))}"'
```

### Database Configuration

Database settings are in `config/database.yml`. Default configuration:
- **Development**: `uni_hub_development`
- **Test**: `uni_hub_test`
- **Production**: Uses `DATABASE_URL` environment variable

### Environment Variables

```bash
# Required for AI features
OPENAI_API_KEY=sk-your-key-here

# Production
DATABASE_URL=postgresql://user:password@host:port/database
SECRET_KEY_BASE=your-secret-key-base
RAILS_ENV=production
```

## 🧪 Testing

```bash
# Run all tests
rails test

# Run specific test
rails test test/controllers/notes_controller_test.rb

# Run system tests
rails test:system
```

## 📁 Project Structure

```
Uni-Hub/
├── app/
│   ├── controllers/       # Request handlers
│   ├── models/           # Database models
│   ├── views/            # HTML templates
│   ├── services/         # Business logic (OpenAI, etc.)
│   ├── javascript/       # Stimulus controllers
│   └── assets/           # Images, stylesheets
├── config/               # Application configuration
├── db/                   # Database migrations & schema
├── test/                 # Test suite
└── public/               # Static files
```

## 🎯 Usage

### Creating Notes
1. Sign up or log in
2. Click "New Note"
3. Write your content using the rich text editor
4. Add tags and assign to folders
5. Use AI tools to summarize or generate quizzes

### AI Features
- **Summarize**: Get concise summaries of your notes
- **Generate Quiz**: Create practice questions from content
- **Study Hints**: Get helpful learning tips
- **UniHub AI Assistant**: Ask generative questions about study material, schedules, notes, and assignments
- **Learning Pulse**: Review explainable progress status using critical (red), needs attention (orange), and on track (green)

### Assignment Management
1. Navigate to "Assignments"
2. Create new assignment with title, description, and due date
3. Set priority level
4. Track progress and mark as complete

## 🚢 Deployment

### Using Kamal (Recommended)

```bash
# Setup deploy config
cp config/deploy.yml.example config/deploy.yml

# Edit with your settings
nano config/deploy.yml

# Deploy
kamal setup
kamal deploy
```

### Using Heroku

```bash
# Create app
heroku create your-app-name

# Add PostgreSQL
heroku addons:create heroku-postgresql

# Set environment variables
heroku config:set OPENAI_API_KEY=sk-your-key-here

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Using Docker

```bash
# Build image
docker build -t uni-hub .

# Run container
docker run -p 3000:3000 \
  -e OPENAI_API_KEY=sk-your-key-here \
  -e DATABASE_URL=postgresql://... \
  uni-hub
```

## 🔒 Security

- API keys are stored in environment variables or encrypted credentials
- User authentication via Devise
- CSRF protection enabled
- Content Security Policy configured
- SQL injection protection via ActiveRecord
- XSS protection via Rails auto-escaping

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License.

## 🆘 Support

### Common Issues

**AI features not working:**
- Check OpenAI API key is configured: See [OPENAI_SETUP.md](../OPENAI_SETUP.md)
- Verify API key: `rails runner "puts ENV['OPENAI_API_KEY']"`
- Check Rails logs: `tail -f log/development.log`

**Database connection errors:**
- Ensure PostgreSQL is running
- Check `config/database.yml` settings
- Run `rails db:create db:migrate`

**Asset compilation issues:**
- Clear cache: `rails assets:clobber`
- Precompile: `rails assets:precompile`

### Getting Help

- Check [OPENAI_SETUP.md](../OPENAI_SETUP.md) for AI configuration
- Review logs in `log/development.log`
- Open an issue on GitHub

## 🙏 Acknowledgments

- Built with Ruby on Rails
- AI powered by OpenAI
- Styled with Tailwind CSS
- Icons from Heroicons

---

Made with ❤️ for university students
