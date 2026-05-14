# UniHub Mobile Migration Implementation Plan

**Objective:** Migrate UniHub from Rails Turbo frontend to React Native mobile app (iOS/Android) while keeping Rails backend and AI features intact.

**Timeline Estimate:** 10–14 weeks  
**Team Size Recommendation:** 2–3 developers (1 backend/API, 1–2 frontend/React Native)

---

## Branching & Design Governance

- **Separate feature branch:** Use a dedicated branch for the mobile migration, e.g. `feature/mobile-react-native` or `mobile/app`.
- **Branch naming convention:** `feature/mobile/<feature>` for new functionality, `fix/mobile/<issue>` for bug fixes, `chore/mobile/<maintenance>`.
- **Protected branches:** Keep `main` and `develop` protected. Require pull request review, passing CI, and at least one peer approval before merge.
- **Design sign-off:** All UI/UX pull requests must include a design lead or product owner review and a design QA checklist.
- **Design system enforcement:** Establish a shared mobile design system before component development, including:
  - color palette, typography, and spacing tokens
  - reusable components for buttons, cards, inputs, headers, and lists
  - layout and motion rules for mobile UX
  - accessibility, form behavior, and responsive mobile patterns
- **Documentation:** Maintain the mobile design system in the mobile project repository, ideally under `docs/design` or `README.md`.
- **Professional UI checks:** Every release candidate must pass a mobile design QA checklist covering visual consistency, spacing, typography, iconography, and touch behavior.

---

## Phase 0: Planning & Setup (Week 1)

### 0.1 Backend Architecture Review
- **Task:** Audit existing Rails models and controllers to identify API candidates
- **Deliverable:** 
  - List of core models: User, Note, Assignment, Submission, Schedule, AttendanceList, Quiz, Summarization
  - Identify which controllers already support JSON responses
  - Map AI service integrations (OpenAI for summarization, Gemini for quiz generation)
- **Owner:** Backend Lead
- **Effort:** 1 day

### 0.2 Design API Schema
- **Task:** Define RESTful JSON endpoints for mobile app
- **Deliverable:** API documentation (Swagger/OpenAPI spec) covering:
  - Authentication (`POST /api/v1/auth/login`, `POST /api/v1/auth/logout`, `GET /api/v1/auth/current_user`)
  - Notes CRUD + Summarization
  - Assignments + Submissions
  - Schedules + Enrollments
  - Attendance Lists + Marking
  - Quizzes + Results
  - Messages + Conversations
  - Push Notifications
- **Owner:** Backend Lead
- **Effort:** 1–2 days

### 0.3 React Native Project Scaffold
- **Task:** Set up new React Native project
- **Deliverable:**
  - Initialize project with Expo or React Native CLI
  - Set up folder structure: `screens/`, `components/`, `services/`, `context/`, `utils/`
  - Install core dependencies: React Navigation, Axios, Redux/Context, native libraries
  - Set up GitHub repo for mobile app (separate from Rails repo or new branch)
  - Establish the first mobile design system artifacts: theme tokens, base typography, shared spacing, and component skeletons
- **Owner:** Frontend Lead
- **Effort:** 1 day

### 0.4 Define Testing & Deployment Strategy
- **Task:** Plan mobile app testing and distribution
- **Deliverable:**
  - Define testing pyramid: unit tests (Jest), component tests (React Native Testing Library), E2E (Detox)
  - Plan app store submission timeline (TestFlight, Google Play Beta)
  - Set up CI/CD pipeline (GitHub Actions for build + upload to stores)
- **Owner:** Both Leads
- **Effort:** 0.5 day

---

## Phase 1: Backend API Foundation (Weeks 2–3)

### 1.1 Set Up API Namespace & Authentication
- **Task:** Create Rails API controller structure with token-based auth
- **Deliverable:**
  - Add `app/controllers/api/v1/` controllers
  - Implement `devise_token_auth` or JWT-based authentication
  - Create `api/v1/base_controller.rb` with shared auth logic
  - Add auth endpoints: `login`, `logout`, `refresh_token`, `current_user`
  - Configure CORS for mobile client requests
- **Owner:** Backend Lead
- **Effort:** 3–4 days

### 1.2 Implement Core Resource APIs
- **Task:** Build JSON endpoints for all core features
- **Deliverable:**
  - `api/v1/notes_controller.rb` (CRUD + summarization trigger)
  - `api/v1/assignments_controller.rb` + `submissions_controller.rb`
  - `api/v1/schedules_controller.rb` + `enrollments_controller.rb`
  - `api/v1/attendance_lists_controller.rb` + `records_controller.rb`
  - `api/v1/quizzes_controller.rb` (CRUD + submission handling)
  - `api/v1/messages_controller.rb` + `conversations_controller.rb`
  - Serializers for each resource (using `active_model_serializers` or `fast_jsonapi`)
- **Owner:** Backend Lead
- **Effort:** 4–5 days

### 1.3 Add Summarization & Quiz Generation APIs
- **Task:** Expose AI features via API
- **Deliverable:**
  - `POST /api/v1/summarizations/create` (accepts text, returns summary)
  - `POST /api/v1/quizzes/generate_from_note` (accepts note_id, returns quiz)
  - Both async with job tracking (using Sidekiq or similar)
  - Webhook or polling endpoint for job status
- **Owner:** Backend Lead
- **Effort:** 2–3 days

### 1.4 Add Push Notification Subscription API
- **Task:** Support mobile push notifications (FCM/APNs)
- **Deliverable:**
  - `POST /api/v1/devices/register` (FCM/APNs token registration)
  - Model: `Device` with `device_token`, `platform` (ios/android)
  - Integration with existing push notification system
  - Test push endpoint for mobile testing
- **Owner:** Backend Lead
- **Effort:** 2 days

### 1.5 Write & Run API Tests
- **Task:** Ensure all endpoints work as expected
- **Deliverable:**
  - RSpec tests for all API controllers
  - Test authentication, CRUD, error handling
  - Mock external AI services
  - Postman collection for manual testing
- **Owner:** Backend Lead
- **Effort:** 2–3 days

### 1.6 Deploy API to Staging
- **Task:** Deploy Phase 1 to staging environment for mobile dev testing
- **Deliverable:**
  - Staging server with API endpoints live
  - Database seeded with test data (users, notes, assignments, schedules)
  - API documentation accessible to frontend team
- **Owner:** Backend Lead
- **Effort:** 1 day

---

## Phase 2: React Native Setup & Authentication (Weeks 3–4)

### 2.1 Project Structure & Navigation
- **Task:** Set up React Navigation (stack, tab, drawer navigators)
- **Deliverable:**
  - Root navigator setup (auth stack vs. app stack)
  - Bottom tab navigator: Home, Notes, Assignments, Schedule, Messages, Profile
  - Drawer navigator for admin/settings
  - Navigation state management
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 2.2 Authentication Flow
- **Task:** Build login/logout/signup screens and token management
- **Deliverable:**
  - Login screen: email + password
  - Sign-up screen: first name, last name, email, password, role, department
  - Token storage: Secure storage (using `react-native-keychain` for tokens)
  - Context/Redux for auth state (current user, token, loading)
  - Auto-logout on token expiration
  - Auto-login from stored token on app start
- **Owner:** Frontend Lead
- **Effort:** 3–4 days

### 2.3 API Service Layer
- **Task:** Create reusable API clients
- **Deliverable:**
  - `services/api.ts`: Axios instance with interceptors for auth tokens
  - Error handling & retry logic
  - Base URLs for dev/staging/production
  - Request/response logging
- **Owner:** Frontend Lead
- **Effort:** 1–2 days

### 2.4 Testing Authentication Flow
- **Task:** Unit & integration tests for auth
- **Deliverable:**
  - Jest tests for auth context/reducer
  - Integration tests for login/logout flow
  - Mock API responses
- **Owner:** Frontend Lead
- **Effort:** 1–2 days

### 2.5 Mobile Design System & Visual QA
- **Task:** Define and enforce professional mobile UI standards
- **Deliverable:**
  - Mobile design system guide with colors, typography, spacing, and icons
  - Shared component library using NativeWind or approved styling approach
  - Accessibility and mobile interaction rules
  - Visual QA checklist for screens, form inputs, and navigation patterns
- **Owner:** Frontend Lead + Design Lead
- **Effort:** 2 days

---

## Phase 3: Core Features MVP (Weeks 5–8)

### 3.1 Dashboard/Home Screen
- **Task:** Build main dashboard with widgets
- **Deliverable:**
  - Upcoming classes (from schedule)
  - Pending assignments (count + list)
  - Recent notes
  - Quick stats (attendance %, grades if available)
  - Pull-to-refresh to fetch latest data
  - Loading states & error handling
- **Owner:** Frontend Lead
- **Effort:** 3–4 days

### 3.2 Notes & Summarization Feature
- **Task:** Build full note CRUD + text summarization
- **Deliverable:**
  - Notes list screen (pagination, search, filter by subject)
  - Create note screen: title + rich text editor (using `react-native-rich-text-editor` or similar)
  - Note detail screen: view, edit, delete, share
  - Summarize button: trigger backend summarization, show results in modal
  - Export note as PDF/Markdown
- **Owner:** Frontend Lead
- **Effort:** 5–6 days

### 3.3 Assignments & Submissions
- **Task:** Build assignment viewing and submission workflow
- **Deliverable:**
  - Assignments list: filter by status (pending, submitted, graded)
  - Assignment detail: description, due date, submission status
  - Submit assignment: file picker (photos, documents), text input, upload progress
  - View previous submissions with feedback
  - Search assignments
- **Owner:** Frontend Lead
- **Effort:** 4–5 days

### 3.4 Schedule & Attendance
- **Task:** Build schedule viewing and attendance marking
- **Deliverable:**
  - Schedule screen: weekly/monthly view with enrolled classes
  - Class detail: instructor, room, enrolled students (for teachers)
  - Enroll/unenroll in schedule
  - Attendance list screen: QR code scanner or manual list for teachers
  - Student attendance marking: simple check-in flow
  - Notifications: class reminders 15 minutes before
- **Owner:** Frontend Lead
- **Effort:** 4–5 days

### 3.5 Messages & Real-Time Communication
- **Task:** Build messaging UI with real-time updates
- **Deliverable:**
  - Conversations list: sorted by latest message
  - Chat screen: message list, input field, send button
  - Real-time updates: WebSocket or polling for new messages
  - Typing indicators (optional for MVP)
  - Message search
- **Owner:** Frontend Lead
- **Effort:** 3–4 days

### 3.6 User Profile & Settings
- **Task:** Build profile and settings screens
- **Deliverable:**
  - Profile screen: user info, profile picture, edit button
  - Settings screen: theme (dark/light), notifications toggle, language
  - Logout button
  - Account deletion option
- **Owner:** Frontend Lead
- **Effort:** 1–2 days

### 3.7 Testing MVP Features
- **Task:** End-to-end testing of all MVP features
- **Deliverable:**
  - Component tests for key screens
  - Integration tests for workflows (login → create note → summarize)
  - Manual testing on iOS/Android simulators
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

---

## Phase 4: Advanced Features (Weeks 9–11)

### 4.1 Quiz Generation & Taking
- **Task:** Build quiz creation from notes and quiz-taking UI
- **Deliverable:**
  - Quiz list screen
  - "Generate quiz from note" workflow
  - Quiz-taking screen: questions, multiple choice/fill-in
  - Quiz results screen with score breakdown
  - Quiz history
- **Owner:** Frontend Lead
- **Effort:** 4–5 days

### 4.2 Push Notifications
- **Task:** Implement native push notifications
- **Deliverable:**
  - Register device token on app start
  - Handle push notification payload (navigate to relevant screen)
  - Notification permission request (iOS 13+)
  - Local testing with backend push endpoint
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 4.3 Offline Support
- **Task:** Add offline-first caching for key data
- **Deliverable:**
  - `AsyncStorage` for user session
  - SQLite or Realm for note/schedule cache
  - Sync on reconnect
  - Offline indicators in UI
- **Owner:** Frontend Lead
- **Effort:** 3–4 days

### 4.4 File Uploads & Camera Integration
- **Task:** Enhance file handling for assignment submissions
- **Deliverable:**
  - Camera access for taking photos of work
  - Photo library picker
  - Document picker for PDFs/Word docs
  - Multi-file uploads
  - Upload progress tracking
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 4.5 Search & Advanced Filtering
- **Task:** Full-text search across notes, assignments, schedule
- **Deliverable:**
  - Global search screen
  - Filter by date, subject, instructor, status
  - Search suggestions (powered by backend)
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 4.6 Collaboration Features
- **Task:** Real-time note/quiz collaboration (if backend supports)
- **Deliverable:**
  - Invite collaborators to notes
  - Live cursor tracking
  - Comment threads on collaborative content
- **Owner:** Frontend Lead
- **Effort:** 3–4 days (depends on backend support)

### 4.7 Analytics & Insights
- **Task:** Display learning analytics dashboard
- **Deliverable:**
  - Student: grades, attendance %, assignment completion rate
  - Teacher: class participation, submission rates, quiz performance
  - Graphs using a charting library (e.g., `react-native-chart-kit`)
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

---

## Phase 5: Testing, Optimization & Deployment (Weeks 12–14)

### 5.1 Performance Optimization
- **Task:** Optimize app performance and bundle size
- **Deliverable:**
  - Code splitting for screens
  - Image optimization
  - Lazy loading of lists
  - Performance profiling with React DevTools
  - Target: app loads in < 3 seconds, smooth 60 FPS scrolling
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 5.2 Accessibility & Localization
- **Task:** Ensure app is accessible and supports multiple languages
- **Deliverable:**
  - Screen reader support (VoiceOver/TalkBack)
  - High contrast mode
  - i18n setup with common languages (English, Spanish, French, etc.)
- **Owner:** Frontend Lead
- **Effort:** 2–3 days

### 5.3 End-to-End Testing
- **Task:** Comprehensive testing on real devices
- **Deliverable:**
  - Test suite using Detox (E2E testing framework for React Native)
  - Manual QA checklist covering all features
  - Bug fixes and edge case handling
- **Owner:** Frontend Lead + QA
- **Effort:** 3–4 days

### 5.4 Security & Compliance
- **Task:** Security audit and compliance checks
- **Deliverable:**
  - Token security (no hardcoded secrets)
  - API rate limiting
  - Input validation
  - Sensitive data encryption at rest
  - GDPR/privacy compliance review
- **Owner:** Backend Lead + Frontend Lead
- **Effort:** 2–3 days

### 5.5 App Store Submission
- **Task:** Prepare and submit to app stores
- **Deliverable:**
  - App icons, screenshots, description (iOS App Store, Google Play)
  - Privacy policy + terms of service
  - TestFlight (iOS) and Google Play Internal Testing (Android)
  - Initial app release or beta rollout
- **Owner:** Frontend Lead + DevOps
- **Effort:** 2–3 days

### 5.6 Post-Launch Monitoring
- **Task:** Set up crash reporting and analytics
- **Deliverable:**
  - Sentry or Bugsnag for crash tracking
  - Amplitude or Mixpanel for usage analytics
  - Dashboard for monitoring app health
- **Owner:** DevOps
- **Effort:** 1–2 days

---

## Parallel Work Streams

While the phases are sequential, some tasks can happen in parallel:

### Stream A: Backend (Weeks 1–6)
- Phase 0 planning → Phase 1 API implementation → Phase 1 testing & staging deployment

### Stream B: Frontend (Weeks 3–14)
- Phase 0 planning → Phase 2 setup → Phase 3 MVP → Phase 4 advanced → Phase 5 testing & deployment

### Stream C: DevOps (Weeks 1–14)
- CI/CD pipeline setup
- Staging & production environment management
- App store credentials & provisioning
- Monitoring setup

**Overlap:** By Week 3, backend API is mostly ready for frontend to start integration testing.

---

## Key Dependencies & Risks

### Dependencies
- Backend API must be stable before frontend screens are built
- Authentication must work before any other feature can be tested
- Staging environment critical for frontend testing

### Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| AI services (OpenAI/Gemini) rate limits | High | Implement request queuing, fallback placeholders, daily limits |
| Real-time messaging performance | High | Load test WebSocket/polling; consider using Socket.io or ActionCable from Rails |
| Large note/document handling | Medium | Implement pagination, chunked uploads, file size limits |
| App store approval delays | Medium | Submit 2 weeks before launch; prepare for common rejection reasons |
| Token/auth edge cases | High | Thorough testing; manual refresh token rotation |
| Cross-platform bugs (iOS vs Android) | Medium | Test on both platforms early; use platform-specific code sparingly |

---

## Success Criteria

### Phase 1 Complete
- [ ] All API endpoints returning correct JSON
- [ ] Authentication working with token storage
- [ ] Staging environment live with test data

### Phase 2 Complete
- [ ] Login/logout flow working end-to-end
- [ ] Auth tokens properly stored and refreshed
- [ ] Navigation structure functional

### Phase 3 Complete
- [ ] MVP features working on iOS and Android simulators
- [ ] User can log in, view notes, submit assignment, mark attendance
- [ ] No critical bugs

### Phase 4 Complete
- [ ] Advanced features tested and functional
- [ ] Performance acceptable (startup < 3s, smooth scrolling)
- [ ] Offline support working

### Phase 5 Complete
- [ ] All tests passing
- [ ] Security audit passed
- [ ] App approved and available on iOS App Store & Google Play

---

## Tools & Tech Stack

### Backend
- **Framework:** Ruby on Rails (existing)
- **API Auth:** `devise_token_auth` or custom JWT
- **Serializers:** `active_model_serializers`
- **Jobs:** Sidekiq for async tasks (summarization, quiz generation)
- **Testing:** RSpec
- **API Docs:** Swagger/OpenAPI

### Frontend
- **Framework:** React Native (Expo or React Native CLI)
- **Navigation:** React Navigation
- **State Management:** Context API or Redux
- **API Client:** Axios
- **Storage:** `react-native-keychain` (tokens), `@react-native-async-storage/async-storage` (cache)
- **Database:** Realm or SQLite (for offline cache)
- **UI Components:** React Native Paper or Native Base
- **Rich Text Editor:** `react-native-rich-text-editor` or similar
- **Testing:** Jest, React Native Testing Library, Detox
- **Crash Reporting:** Sentry or Bugsnag
- **Analytics:** Amplitude or Mixpanel

### DevOps & Deployment
- **CI/CD:** GitHub Actions
- **App Stores:** TestFlight (iOS), Google Play (Android)
- **Monitoring:** Sentry, CloudFlare or similar
- **Version Control:** GitHub (separate repo or monorepo)

---

## Resource Allocation

### Backend Developer (1 FTE)
- Weeks 1–3: API development & testing
- Weeks 4–6: Fine-tuning, security, deployment
- Weeks 7–14: Maintenance, bug fixes, feature refinements

### Frontend Developer (1–2 FTE)
- Weeks 1–2: Setup, navigation, auth
- Weeks 3–8: MVP features
- Weeks 9–11: Advanced features
- Weeks 12–14: Testing, optimization, deployment

### DevOps/QA (0.5 FTE)
- Weeks 1–14: CI/CD, testing infrastructure, deployment, monitoring

---

## Communication & Checkpoints

### Weekly Sync (30 min)
- Backend & frontend blockers
- Integration issues
- Progress updates

### Bi-weekly Demo (1 hour)
- Show completed features to stakeholders
- Gather feedback
- Adjust priorities if needed

### Monthly Retrospective (1 hour)
- What went well
- What needs improvement
- Next month's focus

---

## Post-Launch Roadmap (Future)

Once MVP is live:
1. **Analytics Dashboard:** In-depth learning insights for students/teachers
2. **Video Conferencing:** Integrate Zoom/Teams for live classes
3. **AI Tutoring:** Personalized study recommendations
4. **Wearable Integration:** Fitness tracking, focus time management
5. **Web App:** React or Vue.js version alongside mobile app

---

## Next Steps

1. **Immediate (This Week):**
   - Schedule kickoff meeting with backend & frontend leads
   - Create GitHub issue tracker for all tasks above
   - Set up staging environment
   - Define API schema in detail

2. **Week 1:**
   - Begin Phase 0 & Phase 1 work in parallel
   - Set up project repos and CI/CD pipelines

3. **Week 3:**
   - Phase 1 API endpoints ready for testing
   - Frontend team begins Phase 2 setup
   - First integration test: login flow

---

**Document Version:** 1.0  
**Last Updated:** May 13, 2026  
**Owner:** Project Lead
