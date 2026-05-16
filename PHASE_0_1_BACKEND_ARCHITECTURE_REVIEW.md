# Phase 0.1: Backend Architecture Review

**Completed:** May 16, 2026  
**Status:** ✅ Complete  
**Effort:** 1 day

---

## Executive Summary

The Rails backend has a mature, well-structured architecture with all core models, services, and controllers needed to support the React Native mobile app. The existing codebase includes:

- **16 core domain models** suitable for API exposure
- **Comprehensive authentication** via Devise (can be adapted for mobile token auth)
- **AI service factory pattern** with OpenAI and Gemini provider support
- **Real-time infrastructure** via ActionCable
- **Policy-based authorization** via Pundit

**Recommendation:** Proceed directly to Phase 1 API implementation. No architectural refactoring needed.

---

## 1. Core Models Audit

### Tier 1: Essential for MVP

| Model | Purpose | Relationships | API Priority | Status |
|-------|---------|---------------|--------------|--------|
| **User** | User identity & roles | Owns notes, assignments, quizzes, schedules, messages | ⭐⭐⭐ | Ready |
| **Note** | Student notes with versioning | Belongs to user/folder, has tags, shareable, can generate quizzes | ⭐⭐⭐ | Ready |
| **Assignment** | Teacher assignments & submissions | User creates, students submit | ⭐⭐⭐ | Ready |
| **Submission** | Student assignment work | Belongs to user/assignment, versioned | ⭐⭐⭐ | Ready |
| **Schedule** | Class schedules/timetables | User-based, has participants, attendance lists | ⭐⭐⭐ | Ready |
| **AttendanceList** | Class attendance tracking | Belongs to schedule, has records | ⭐⭐⭐ | Ready |
| **AttendanceRecord** | Individual attendance marks | Belongs to list/user | ⭐⭐⭐ | Ready |
| **Quiz** | Quiz creation & attempts | Belongs to user/note, has questions, attempts | ⭐⭐⭐ | Ready |
| **QuizQuestion** | Quiz question items | Belongs to quiz | ⭐⭐⭐ | Ready |
| **QuizAttempt** | Student quiz submissions | Belongs to user/quiz | ⭐⭐⭐ | Ready |
| **ChatMessage** | Direct messages between users | Sender/recipient pattern | ⭐⭐⭐ | Ready |
| **Department** | Academic departments | Has many users, notes, assignments | ⭐⭐ | Ready |
| **Folder** | Note organization | Belongs to user, has many notes | ⭐⭐ | Ready |
| **Tag** | Note/quiz tagging | Many-to-many with notes/quizzes | ⭐⭐ | Ready |
| **Notification** | User notifications | Belongs to user, polymorphic | ⭐⭐ | Ready |

### Tier 2: Advanced Features (Phase 4+)

| Model | Purpose | Status |
|-------|---------|--------|
| **Discussion** | Discussion threads | Ready but Phase 4 |
| **DiscussionPost** | Discussion posts | Ready but Phase 4 |
| **ContentTemplate** | Content templates | Ready but Phase 4 |
| **Summarization** | AI summarization jobs (not a model, handled by service) | Ready |
| **ComplianceReport** | Compliance tracking | Ready but Phase 4+ |
| **AnalyticsMetric** | Usage analytics | Ready but Phase 4+ |

---

## 2. Existing Controllers Audit

### API-Ready Controllers (Current Structure)

**Currently Web-Only (render HTML):**
- `NotesController` - Full CRUD implemented
- `AssignmentsController` - Full CRUD
- `SubmissionsController` - Full CRUD
- `SchedulesController` - Full CRUD
- `AttendanceListsController` & `AttendanceRecordsController`
- `QuizzesController` - Full CRUD
- `MessagesController` - Index/Show/Create/Destroy with search
- `UsersController` - Profile management
- `SummarizationsController` - Text summarization

**Observations:**
- All controllers use `authorize` from Pundit (good for authorization)
- Most actions render ERB templates
- `render json:` patterns exist for username/email checks
- No dedicated API namespace yet (`/api/v1/`)

---

## 3. Authentication & Authorization

### Current Setup
- **Framework:** Devise with `:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`
- **Authorization:** Pundit for policy-based authorization
- **Session Management:** Session cookies (web-based)

### For Mobile App
- **Recommendation:** Implement JWT token-based authentication via `devise_token_auth` gem (recommended for React Native + Rails)
- **Plan:**
  1. Keep existing Devise for web
  2. Add `devise_token_auth` for mobile API with:
     - Access token (short-lived, ~1 hour)
     - Refresh token (long-lived, ~30 days)
     - Reuse existing User model (no migration needed)

---

## 4. AI Service Integration

### Current Architecture

**Provider Factory Pattern:**
```ruby
AiServiceFactory.provider.summarize_text(text, length: :medium)
```

**Supported Providers:**
1. **OpenAI** (via `AiProviders::OpenaiProvider`)
   - `summarize_text(text, length:, user_id:)`
   - Configured via `OPENAI_API_KEY` env var

2. **Gemini** (via `AiProviders::GeminiProvider`)
   - Same interface as OpenAI
   - Configured via `GEMINI_API_KEY` env var

3. **Mock Provider** (for testing/development)

### For Mobile App
- **Summarization API:** Expose `POST /api/v1/summarizations/create`
- **Quiz Generation API:** Expose `POST /api/v1/quizzes/generate` (async job pattern)
- **Implementation:** Reuse existing services, wrap in API controllers

---

## 5. Real-Time Infrastructure

### ActionCable Setup
- Already configured for real-time messaging
- Supports WebSocket connections (mobile apps need HTTP polling fallback or WebSocket client)

### For Mobile Integration
- **Messages:** Use HTTP polling initially (Phase 3), upgrade to WebSocket client in Phase 4
- **Notifications:** Use push notification service (FCM/APNs) instead of ActionCable

---

## 6. Dependencies & Gems

### Already Installed & Suitable
- ✅ **devise** - Authentication
- ✅ **pundit** - Authorization  
- ✅ **active_model_serializers** or manual JSON serialization - for API responses
- ✅ **sidekiq** (if configured) - Async jobs for AI processing

### Recommended Additions for Mobile API
- **devise_token_auth** - JWT authentication for mobile
- **kaminari** or **pagy** - Pagination for API responses
- **rack-cors** - Enable CORS for mobile client
- **active_model_serializers** - Consistent JSON serialization (if not already used heavily)

---

## 7. Database Schema Observations

### Strengths
- ✅ Well-normalized schema with proper foreign keys
- ✅ Timestamps (`created_at`, `updated_at`) on all models
- ✅ Soft-delete patterns where needed (archived status)
- ✅ Versioning support via `Versionable` concern

### No Changes Needed
- Schema is production-ready for mobile API

---

## 8. Scalability Considerations

### Current Bottlenecks (Addressed in Phase 5)
- N+1 queries (mitigate with `includes` in API serializers)
- Real-time messaging via ActionCable (scale with Redis)
- AI job processing (use Sidekiq background workers)

### Recommendations (Phase 5+)
- Add database indexing on frequently queried fields
- Cache API responses with Redis for read-heavy endpoints
- Implement rate limiting on AI endpoints
- Use CDN for uploaded files

---

## 9. Security Audit

### Existing Protections
- ✅ Devise password hashing
- ✅ Pundit authorization checks
- ✅ CSRF token protection (web)
- ✅ SQL injection prevention (Rails ORM)

### For Mobile API
- Add CORS configuration
- Implement rate limiting per user/API key
- Use HTTPS only (enforce in deployment)
- Add JWT token expiration & rotation strategy
- Validate file uploads (size, MIME type)

---

## 10. API Controllers to Create (Phase 1)

```
app/controllers/api/v1/
├── base_controller.rb              # Shared auth & error handling
├── authentication_controller.rb    # Login, logout, refresh
├── users_controller.rb             # Profile, update
├── notes_controller.rb             # CRUD + summarization
├── assignments_controller.rb       # Teacher assignment CRUD
├── submissions_controller.rb       # Student submission CRUD
├── schedules_controller.rb         # Schedule CRUD + enrollment
├── attendance_lists_controller.rb  # Attendance CRUD
├── attendance_records_controller.rb
├── quizzes_controller.rb           # Quiz CRUD + generation
├── quiz_questions_controller.rb
├── quiz_attempts_controller.rb
├── messages_controller.rb          # Direct messaging
└── devices_controller.rb           # Push notification registration
```

---

## 11. Serializers/JSON Response Format

### Recommended Pattern

```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "Sample Note",
    "content": "...",
    "created_at": "2026-05-16T10:00:00Z"
  },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 100
  }
}
```

### Error Responses

```json
{
  "success": false,
  "error": {
    "status": 401,
    "message": "Invalid credentials",
    "code": "AUTH_FAILED"
  }
}
```

---

## 12. Conclusion

**Overall Assessment:** ✅ **Green Light**

The Rails backend is production-ready for mobile API development. All core models, services, and patterns are in place. No architectural changes needed. 

**Next Step:** Proceed to Phase 0.2 (Design API Schema) and Phase 1 (Backend API Implementation).

---

## Appendix: Model Relationship Diagram

```
User (central hub)
├── owns Notes
│   ├── has Tags
│   └── can generate → Quizzes
├── owns Assignments
│   └── receives Submissions
├── owns Quizzes
│   ├── has QuizQuestions
│   └── has QuizAttempts
├── enrolled in Schedules
│   ├── has AttendanceLists
│   │   └── has AttendanceRecords
│   └── has ScheduleParticipants
├── sends/receives ChatMessages
├── has Notifications
└── belongs to Department
    ├── shared Notes
    ├── shared Quizzes
    └── shared Assignments
```

