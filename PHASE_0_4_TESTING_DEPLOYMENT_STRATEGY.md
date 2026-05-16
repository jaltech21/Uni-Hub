# Phase 0.4: Testing & Deployment Strategy

**Target Completion:** May 17, 2026  
**Status:** 📋 In Progress (Strategy Definition)  
**Effort:** 0.5 day  
**Owner:** Both Backend Lead & Frontend Lead + DevOps

---

## Executive Summary

This document defines the testing pyramid, CI/CD pipeline, and deployment strategy for both backend API and React Native mobile app. Our approach emphasizes quality at every level while maintaining fast iteration cycles.

---

## 1. Testing Pyramid

### 1.1 Backend API Testing Stack

```
         ╔═════════════════════════════╗
         ║    E2E Tests (Minimal)      ║  ← 5% (~10 tests)
         ║  Full workflow integration  ║     Detox or Playwright
         ╠═════════════════════════════╣
         ║  Integration Tests          ║  ← 20% (~40 tests)
         ║  Multi-endpoint flows       ║     RSpec + FactoryBot
         ╠═════════════════════════════╣
         ║  Unit Tests                 ║  ← 75% (~150 tests)
         ║  Models, services, helpers  ║     RSpec, Minitest
         ╚═════════════════════════════╝
```

### 1.2 Frontend (React Native) Testing Stack

```
         ╔═════════════════════════════╗
         ║    E2E Tests                ║  ← 10% (~20 tests)
         ║  Full user workflows        ║     Detox or Cypress Native
         ╠═════════════════════════════╣
         ║  Integration Tests          ║  ← 20% (~40 tests)
         ║  Component interactions     ║     React Native Testing Lib
         ╠═════════════════════════════╣
         ║  Unit Tests                 ║  ← 70% (~140 tests)
         ║  Hooks, utilities, context  ║     Jest, React Testing Library
         ╚═════════════════════════════╝
```

---

## 2. Backend API Testing Strategy

### 2.1 Unit Tests (RSpec)

**What to Test:**
- Model validations
- Model scopes and associations
- Service layer business logic
- Helper methods
- Custom validators

**Example:** `spec/models/note_spec.rb`

```ruby
RSpec.describe Note, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_length_of(:title).is_at_most(200) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:tags) }
  end

  describe '#sufficient_for_quiz?' do
    it 'returns true if content >= 200 chars' do
      note = build(:note, content: 'x' * 200)
      expect(note.sufficient_for_quiz?).to be true
    end
  end
end
```

**Coverage Target:** 85%+ for models and services

---

### 2.2 Integration Tests (RSpec + FactoryBot)

**What to Test:**
- Complete request/response cycles
- API authentication flows
- Authorization policies (Pundit)
- Multi-step workflows
- Error handling

**Example:** `spec/requests/api/v1/notes_spec.rb`

```ruby
RSpec.describe 'API::V1::Notes', type: :request do
  let(:user) { create(:user) }
  let(:note) { create(:note, user: user) }
  
  before { @headers = auth_headers(user) }

  describe 'GET /api/v1/notes' do
    it 'returns user notes with pagination' do
      create_list(:note, 5, user: user)
      
      get '/api/v1/notes', headers: @headers, params: { page: 1, per_page: 10 }
      
      expect(response).to have_http_status(200)
      expect(json_response['data'].length).to eq(5)
      expect(json_response['meta']['total']).to eq(5)
    end

    it 'filters by folder' do
      folder = create(:folder, user: user)
      create(:note, user: user, folder: folder)
      create(:note, user: user, folder: nil)
      
      get '/api/v1/notes', 
          headers: @headers, 
          params: { folder_id: folder.id }
      
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'POST /api/v1/notes' do
    it 'creates note with tags' do
      post '/api/v1/notes',
           headers: @headers,
           params: {
             title: 'New Note',
             content: 'Content here',
             tags: ['react', 'hooks']
           }
      
      expect(response).to have_http_status(201)
      expect(Note.count).to eq(1)
      expect(Note.last.tags.pluck(:name)).to include('react', 'hooks')
    end

    context 'validation errors' do
      it 'returns 422 with errors' do
        post '/api/v1/notes',
             headers: @headers,
             params: { title: '', content: '' }
        
        expect(response).to have_http_status(422)
        expect(json_response['error']['status']).to eq(422)
      end
    end
  end
end
```

**Coverage Target:** 70%+ for controllers

---

### 2.3 API Testing Best Practices

**Authentication Testing:**
```ruby
describe 'authentication' do
  it 'returns 401 if no token provided' do
    get '/api/v1/notes'
    expect(response).to have_http_status(401)
  end

  it 'returns 401 if invalid token' do
    get '/api/v1/notes', headers: { 'Authorization' => 'Bearer invalid' }
    expect(response).to have_http_status(401)
  end

  it 'returns 200 with valid token' do
    get '/api/v1/notes', headers: auth_headers(user)
    expect(response).to have_http_status(200)
  end
end
```

**Authorization Testing (Pundit):**
```ruby
describe 'authorization' do
  it 'allows user to update their own note' do
    put "/api/v1/notes/#{note.id}",
        headers: auth_headers(note.user),
        params: { title: 'Updated' }
    expect(response).to have_http_status(200)
  end

  it 'forbids user from updating others notes' do
    other_user = create(:user)
    put "/api/v1/notes/#{note.id}",
        headers: auth_headers(other_user),
        params: { title: 'Hacked' }
    expect(response).to have_http_status(403)
  end
end
```

**Mocking External Services:**
```ruby
describe 'summarization' do
  it 'calls AI service and returns summary' do
    allow(AiServiceFactory).to receive_message_chain(:provider, :summarize_text)
      .and_return({ success: true, summary: 'Mocked summary' })
    
    post '/api/v1/summarizations/create',
         headers: @headers,
         params: { text: 'x' * 200, length: 'medium' }
    
    expect(response).to have_http_status(200)
    expect(json_response['data']['summary']).to eq('Mocked summary')
  end
end
```

---

### 2.4 Backend Test Execution

**Setup:**
```bash
# Install test gems (add to Gemfile)
group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'faker'
  gem 'webmock'
end

# Setup test database
bundle install
rails db:test:prepare
```

**Run Tests:**
```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/requests/api/v1/notes_spec.rb

# With coverage
COVERAGE=true bundle exec rspec

# Parallel (with parallel_tests gem)
bundle exec parallel_test spec/ --type rspec
```

**CI Configuration (GitHub Actions):**
```yaml
name: Backend Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - run: bundle exec rails db:test:prepare
      
      - run: bundle exec rspec
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage.xml
```

---

## 3. Frontend (React Native) Testing Strategy

### 3.1 Unit Tests (Jest)

**What to Test:**
- Custom hooks (`useAuth`, `useApi`)
- Utility functions
- Context reducers
- Service methods

**Example:** `app/__tests__/hooks/useAuth.test.ts`

```typescript
import { renderHook, act } from '@testing-library/react-native';
import { useAuth } from '@hooks/useAuth';
import { AuthProvider } from '@context/AuthContext';

describe('useAuth Hook', () => {
  it('should provide auth context', () => {
    const wrapper = ({ children }) => <AuthProvider>{children}</AuthProvider>;
    const { result } = renderHook(() => useAuth(), { wrapper });

    expect(result.current).toHaveProperty('user');
    expect(result.current).toHaveProperty('login');
    expect(result.current).toHaveProperty('logout');
  });

  it('should login user successfully', async () => {
    const wrapper = ({ children }) => <AuthProvider>{children}</AuthProvider>;
    const { result } = renderHook(() => useAuth(), { wrapper });

    await act(async () => {
      await result.current.login('test@example.com', 'password123');
    });

    expect(result.current.user).not.toBeNull();
    expect(result.current.user?.email).toBe('test@example.com');
  });
});
```

**Coverage Target:** 80%+ for hooks and utils

---

### 3.2 Component Tests (React Native Testing Library)

**What to Test:**
- Component rendering
- User interactions (button taps, form input)
- Conditional rendering
- Error states

**Example:** `app/__tests__/screens/auth/LoginScreen.test.tsx`

```typescript
import React from 'react';
import { render, fireEvent, waitFor } from '@testing-library/react-native';
import LoginScreen from '@screens/auth/LoginScreen';
import { AuthProvider } from '@context/AuthContext';

describe('LoginScreen', () => {
  it('renders login form', () => {
    const { getByPlaceholderText, getByText } = render(
      <AuthProvider>
        <LoginScreen />
      </AuthProvider>
    );

    expect(getByPlaceholderText(/email/i)).toBeTruthy();
    expect(getByPlaceholderText(/password/i)).toBeTruthy();
    expect(getByText(/sign in/i)).toBeTruthy();
  });

  it('validates email and password on submit', async () => {
    const { getByText } = render(
      <AuthProvider>
        <LoginScreen />
      </AuthProvider>
    );

    fireEvent.press(getByText(/sign in/i));

    await waitFor(() => {
      expect(getByText(/email is required/i)).toBeTruthy();
    });
  });

  it('shows error on failed login', async () => {
    const { getByPlaceholderText, getByText, queryByText } = render(
      <AuthProvider>
        <LoginScreen />
      </AuthProvider>
    );

    fireEvent.changeText(getByPlaceholderText(/email/i), 'invalid@email.com');
    fireEvent.changeText(getByPlaceholderText(/password/i), 'wrongpassword');
    fireEvent.press(getByText(/sign in/i));

    await waitFor(() => {
      expect(queryByText(/invalid credentials/i)).toBeTruthy();
    });
  });
});
```

---

### 3.3 Integration Tests (React Native Testing Library)

**What to Test:**
- Multi-screen workflows
- Navigation flows
- API integration with mocked responses

**Example:** `app/__tests__/integration/auth-flow.test.tsx`

```typescript
import React from 'react';
import { render, fireEvent, waitFor } from '@testing-library/react-native';
import { AuthProvider } from '@context/AuthContext';
import RootNavigator from '@navigation/RootNavigator';

jest.mock('@services/api', () => ({
  default: {
    post: jest.fn(),
  },
}));

describe('Auth Flow Integration', () => {
  it('completes login and navigates to dashboard', async () => {
    const { getByPlaceholderText, getByText, queryByText } = render(
      <AuthProvider>
        <RootNavigator />
      </AuthProvider>
    );

    // Fill login form
    fireEvent.changeText(getByPlaceholderText(/email/i), 'user@example.com');
    fireEvent.changeText(getByPlaceholderText(/password/i), 'password123');

    // Submit
    fireEvent.press(getByText(/sign in/i));

    // Wait for navigation
    await waitFor(() => {
      expect(queryByText(/welcome/i)).toBeTruthy();
    }, { timeout: 3000 });
  });
});
```

---

### 3.4 E2E Tests (Detox)

**What to Test:**
- Complete user workflows
- Navigation paths
- Real device behavior

**Setup:**
```bash
npm install detox-cli detox detox-config-builder -D
npx detox build-framework-cache
```

**Example:** `e2e/authFlow.e2e.ts`

```typescript
describe('Authentication Flow', () => {
  beforeAll(async () => {
    await device.launchApp();
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('should login and navigate to dashboard', async () => {
    await element(by.id('email-input')).typeText('user@example.com');
    await element(by.id('password-input')).typeText('password123');
    await element(by.text('Sign In')).tap();

    await waitFor(element(by.text('Welcome, User')))
      .toBeVisible()
      .withTimeout(5000);
  });

  it('should navigate through all tabs', async () => {
    // Assuming logged in already
    
    await element(by.id('tab-notes')).tap();
    await expect(element(by.text('My Notes'))).toBeVisible();

    await element(by.id('tab-assignments')).tap();
    await expect(element(by.text('Assignments'))).toBeVisible();

    await element(by.id('tab-schedule')).tap();
    await expect(element(by.text('Schedule'))).toBeVisible();
  });
});
```

**Run E2E Tests:**
```bash
# Build app for testing
detox build-framework-cache
detox build-app-ios --configuration Debug

# Run tests
detox test e2e --configuration ios.sim.debug --cleanup
```

---

### 3.5 Frontend Test Execution

**Setup:**
```bash
cd mobile
npm install

# Create test config
echo "module.exports = { preset: 'react-native' };" > jest.config.js
```

**Run Tests:**
```bash
# All unit/integration tests
npm run test

# Watch mode
npm run test -- --watch

# Coverage
npm run test -- --coverage

# Specific test file
npm run test -- __tests__/screens/auth/LoginScreen.test.tsx

# E2E tests
detox test e2e
```

**CI Configuration (GitHub Actions for React Native):**
```yaml
name: Mobile Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - run: cd mobile && npm install

      - run: npm run lint
      
      - run: npm run type-check
      
      - run: npm run test -- --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          directory: ./mobile/coverage
```

---

## 4. Continuous Integration Pipeline

### 4.1 GitHub Actions Workflow

**File:** `.github/workflows/ci.yml`

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop, 'feature/**', 'fix/**']
  pull_request:
    branches: [main, develop]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
      - run: cd Uni-Hub && bundle exec rails db:test:prepare
      - run: cd Uni-Hub && bundle exec rspec
      - name: Upload coverage
        uses: codecov/codecov-action@v3

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: cd mobile && npm install
      - run: cd mobile && npm run lint
      - run: cd mobile && npm run test -- --coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          directory: ./mobile/coverage

  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONARCLOUD_TOKEN: ${{ secrets.SONARCLOUD_TOKEN }}

  docker-build:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v3
      - uses: docker/build-push-action@v4
        with:
          context: ./Uni-Hub
          push: false
          tags: unihub:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## 5. Deployment Strategy

### 5.1 Backend API Deployment

**Environments:**
1. **Development** (local)
   - Rails: `rails s`
   - Database: local PostgreSQL
   - API: `http://localhost:3000/api/v1`

2. **Staging** (testing before production)
   - Platform: Railway, Render, or Heroku
   - Database: Staging PostgreSQL
   - API: `https://staging-api.unihub.app/api/v1`
   - Auto-deployed from `develop` branch

3. **Production** (live)
   - Platform: Railway, Render, or DigitalOcean
   - Database: Production PostgreSQL (encrypted backups daily)
   - API: `https://api.unihub.app/api/v1`
   - Manual promotion from staging after testing

**Deployment Checklist:**
- [ ] All CI tests pass
- [ ] Database migrations reviewed
- [ ] Secrets configured (.env variables)
- [ ] Backup taken before deployment
- [ ] Health check passes
- [ ] API response time < 500ms
- [ ] Error rate < 0.1%

---

### 5.2 React Native Mobile App Deployment

**Environments:**
1. **Development Build (EAS)**
   - Deployed to team devices for testing
   - Built from `feature/*` branches

2. **TestFlight (iOS)**
   - Staged beta testing
   - Built from `develop` branch
   - Requires Apple Developer account
   - Link shared with QA team

3. **Google Play Internal Testing (Android)**
   - Staged beta testing
   - Built from `develop` branch
   - Requires Google Play Developer account

4. **App Stores (Production)**
   - iOS App Store
   - Google Play Store
   - Released after passing QA on TestFlight/Internal Testing

**Deployment Flow:**

```
Feature Branch
    ↓
Unit/Integration Tests (CI)
    ↓
Develop Branch
    ↓
Build for TestFlight + Play Internal
    ↓
QA Testing (1-2 weeks)
    ↓
Feature Approval
    ↓
Main Branch
    ↓
App Store Release
```

---

### 5.3 EAS Build Configuration

**File:** `mobile/eas.json`

```json
{
  "cli": {
    "version": ">= 5.0.0"
  },
  "build": {
    "development": {
      "development": true,
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      }
    },
    "preview": {
      "distribution": "internal",
      "android": {
        "buildType": "aab"
      }
    },
    "production": {
      "android": {
        "buildType": "aab"
      }
    }
  },
  "submit": {
    "production": {
      "android": {
        "serviceAccount": "@env ANDROID_SERVICE_ACCOUNT",
        "track": "production"
      },
      "ios": {
        "appleId": "@env APPLE_ID",
        "ascAppId": "1234567890"
      }
    }
  }
}
```

---

### 5.4 Release Management

**Version Strategy:** Semantic Versioning (Major.Minor.Patch)

**Release Schedule:**
- **Weekly releases** (Wednesdays, 2 PM UTC) for minor features/fixes
- **Monthly releases** (1st of month) for major features
- **Hotfixes** (as needed) for critical bugs

**Release Notes Template:**
```markdown
## Version 1.2.0 - May 22, 2026

### ✨ Features
- Quiz generation from notes (AI-powered)
- Offline note viewing

### 🐛 Bug Fixes
- Fixed message notifications on Android
- Improved assignment pagination

### 📱 Device Support
- iOS 14.0+ (updated from 13.0)
- Android 10+ (no change)

### 🚀 Performance
- 20% faster note loading
- Reduced app size by 15MB

### 📦 Breaking Changes
- Deprecated `/api/v1/old_endpoint` (use `/new_endpoint` instead)
```

---

## 6. Monitoring & Quality Metrics

### 6.1 Backend Metrics

**Tracking (Phase 5):**
- API response time (target: < 500ms median)
- Error rate (target: < 0.1%)
- Database query performance
- Memory usage
- Active user sessions

**Tools:**
- Sentry for error tracking
- New Relic or DataDog for performance
- CloudWatch for logs

### 6.2 Frontend Metrics

**Tracking (Phase 5):**
- Crash rate (target: < 0.01%)
- App startup time (target: < 3s)
- Navigation performance
- API call success rate (target: > 99%)
- User engagement metrics

**Tools:**
- Firebase Crashlytics
- Amplitude or Mixpanel for analytics
- Bugsnag for error tracking

---

## 7. Rollback Strategy

### 7.1 Backend Rollback

If production deployment has critical issues:

```bash
# Check deployed version
git log --oneline -n 5 main

# Rollback to previous commit
git revert <commit_hash>
git push origin main

# Or immediate rollback (if < 5 min)
heroku releases:rollback
```

**Runbook:** [Kept simple; expand as needed]

### 7.2 Mobile App Rollback

**iOS:** Withdraw update from App Store or delay release
**Android:** Update Play Store listing to previous version (immediate, all users)

---

## 8. Testing Tools & Technologies

### Backend

| Tool | Purpose | Version |
|------|---------|---------|
| RSpec | Testing framework | 6.0+ |
| FactoryBot | Test data | 6.2+ |
| Shoulda-Matchers | Matcher helpers | 5.1+ |
| WebMock | HTTP mocking | 3.18+ |
| Faker | Fake data generation | 3.0+ |
| Simplecov | Coverage reporting | 0.22+ |

### Frontend

| Tool | Purpose | Version |
|------|---------|---------|
| Jest | Testing framework | 29.7+ |
| React Native Testing Library | Component testing | 12.4+ |
| Detox | E2E testing | 20.0+ |
| @testing-library/react-native | DOM queries | 12.4+ |

---

## 9. Success Criteria

**Phase 1 API Testing:**
- ✅ 75%+ backend code coverage
- ✅ All API endpoints tested (both success & error cases)
- ✅ Zero security vulnerabilities in OWASP Top 10
- ✅ All CI tests pass before merge to develop

**Phase 2 Frontend Testing:**
- ✅ 70%+ React Native code coverage
- ✅ All screens can be rendered
- ✅ Auth flow E2E test passes
- ✅ All CI tests pass before merge to develop

**Phase 3+ Ongoing:**
- ✅ All new features include tests (TDD or after-implementation)
- ✅ Coverage maintained ≥ 70%
- ✅ E2E tests cover all critical user paths
- ✅ Production zero-downtime deployments

---

## 10. Next Steps

1. **Weeks 2-3:** Implement backend API with RSpec tests
2. **Weeks 3-4:** Implement React Native auth flow with Jest tests
3. **Week 5:** Add E2E tests for core MVP workflows
4. **Week 12:** Performance & security testing (Phase 5)
5. **Week 13:** Final QA & app store submission prep

---

