# UniHub Mobile — Modular Execution Plan

Goal: bring the mobile app to **feature parity with the web application** — clean UI/UX, **role-based access** and an **active admin panel**, delivered as **modules** (notes, assignments, schedule, etc. separated) so each feature area can be implemented, tested, and recorded independently.

## Baseline (verified by audits)

### Backend (`Uni-Hub/` — Rails 8.0.2)
`/api/v1` currently exposes **only 12 endpoints**:

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/login`, `POST /auth/register`, `POST /auth/refresh`, `GET /auth/current_user`, `DELETE /auth/logout` |
| AI | `POST /ai/summarize`, `GET /ai/progress` |
| Notes | `GET/POST /notes`, `GET/PATCH/DELETE /notes/:id` |

**Everything else exists only as web routes (no `/api/v1` equivalent):**
- Assignments + Submissions (CRUD, nested), Quizzes (+ take/submit/generate/results), Schedules (+ enroll/unenroll/browse), Enrollments, Attendance (lists + records + checkin), Announcements (+ publish/unpublish/toggle_pin), Discussions (+ posts/replies/search), Messages (+ conversations/mark_as_read/search_users), Notifications (+ unread_count/mark_all/recent), Folders, Search (+ results/suggestions), Dashboard widgets, Collaboration sessions, Content sharing/templates, Summarizations, Learning insights, Version history, AI grading + plagiarism, department management, analytics/BI/compliance suites.
- **Admin panel** exists only as web controllers (`Admin::*` + `AdminPanel::*`) rendering HTML — no `/api/v1/admin/*`.

### Backend conventions to reuse (from `base_controller.rb` + `notes_controller.rb`)
- JWT: `Authorization: Bearer <token>`, payload `type == "access"`, `sub` = user id; `active_for_authentication?`.
- Response helpers: `render_success(data, status:, meta:)`, `render_message(message, status:)`, `render_error(message, status:, code:, errors:)`.
- Error codes: 401 `TOKEN_INVALID`/`TOKEN_EXPIRED`, 403 `FORBIDDEN` (Pundit), 404 `NOT_FOUND`, 422 `VALIDATION_ERROR`, 400 `BAD_REQUEST`.
- Pagination: Kaminari `paginate` (default 20, cap 100) + `pagination_meta` → `{page, per_page, total, total_pages}`.
- Note JSON shape: `{ id, title, content, folder_id, folder_name, tags: [{id, name}], created_at, updated_at }`. `policy_scope` + `authorize` via Pundit.

### Mobile (`mobile/` — Expo ~50 / RN 0.73.6 / TS / NativeWind / React Navigation v6)
- Real entry `index.js` → `AuthProvider` > `RootNavigator` (React Navigation). `app/_layout.tsx` + `app/index.tsx` are **vestigial expo-router stubs** (expo-router NOT installed → tsc error).
- 7 tabs: Home, Notes, Assignments, Schedule, Messages, Profile, AI.
  - Wired to API: Notes (list/create), AI (progress/summarize + PDF). **Static placeholders:** Home, Assignments, Schedule, Messages. Profile partially wired (logout works).
- `AuthContext` computes `isAdmin/isTeacher/isStudent` but **nobody consumes them** — no role gating, no admin screens.
- Dead/incorrect service code: `updateProfile`→`PUT /auth/profile` (DNE), `changePassword`→`POST /auth/change_password` (DNE), `resetPassword`→`POST /auth/forgot_password` (DNE). Logout already fixed to `DELETE`. `getStoredToken` exists on both `AuthService` + `apiClient`.
- RegisterScreen: role restricted to student/teacher, hardcodes `department_id: 1`.
- Tests: jest-expo preset + `jest.setup.js` (AsyncStorage + keychain mocks); 1 file `app/__tests__/LoginScreen.test.tsx` (8 tests).

---

## Modules

### Module A — Test Infrastructure (baseline)
- [x] jest-expo preset wired; `jest.setup.js` mocks AsyncStorage + react-native-keychain.
- [x] `LoginScreen.test.tsx` (8 tests) present.
- [ ] Run `npx jest` baseline + record in test log.
- [ ] Fix 4 tsc errors:
  1. `app/__tests__/LoginScreen.test.tsx:58` unused `getAllByText`.
  2. `app/index.tsx` cannot find `expo-router` (vestigial — delete `app/_layout.tsx` + `app/index.tsx`; entry is `index.js`).
  3. `app/screens/app/AIAssistantScreen.tsx:20-21` unused `sourceLength`, `summaryLength`.
- [ ] Remove duplicate `jest.setTimeout(120000)` in test file.

### Module B — API Service Layer (mobile)
- [ ] Extend `types/index.ts`: `Assignment`, `Submission`, `Schedule`, `Enrollment`, `Notification`, `Message/Conversation`, `Quiz`, `Folder`, `AdminUser`, `Department`, `Course`, `Reports`.
- [ ] New services: `AssignmentService`, `ScheduleService`, `MessageService`, `NotificationService`, `FolderService`, `QuizService`, `AdminService` (users/departments/courses/schedules/announcements), `AnnouncementService`, `EnrollmentService`.
- [ ] Remove/guard dead `updateProfile`/`changePassword`/`resetPassword` until backend rotates them in (Module G).

### Module C — Role-Based Access + Admin Panel
- [ ] `RootNavigator`: gate by role.
  - Student/teacher: current 7 tabs (role-appropriate content).
  - **Admin**: admin stack/tabs — Dashboard, Users, Departments, Courses, Schedules (approve/cancel), Announcements.
- [ ] Admin screens: `AdminDashboardScreen`, `AdminUsersScreen`, `AdminDepartmentsScreen`, `AdminCoursesScreen`, `AdminSchedulesScreen`, `AdminAnnouncementsScreen`.
- [ ] Backend: `Api::V1::Admin::*` controllers gated to `user.role == "admin"` (Pundit `AdminPolicy`), reusing `AdminPanel::*` logic/models.

### Module D — Feature-Parity Screens (wire placeholders to API)
- [ ] **Home**: real stats (classes today, assignments due, notes count), today's schedule, upcoming tasks — from `/home/stats` (new) or compose from `/ai/progress` + `/schedules` + `/assignments`.
- [ ] **Assignments**: list with status (due soon / submitted / graded), filter; submit dialog → `AssignmentService`.
- [ ] **Schedule**: day/week view from `/schedules`; enroll/unenroll for students.
- [ ] **Messages**: conversation list, thread, compose, mark-as-read, search users → `MessageService`.
- [ ] **Notifications**: unread badge (header or bell) + list + mark-all-read → `NotificationService`.
- [ ] **Profile**: wire edit profile / change password once backend endpoints exist; keep logout.
- [ ] **Notes + AI**: already wired — add edit/delete/folders/tags polish (low priority).

### Module E — UI/UX Cleanup
- [ ] Shared `components/` kit: `ScreenHeader`, `EmptyState`, `StatCard`, `ListRow`, `Button`, `TextField`, `Badge`, `LoadingSkeleton`.
- [ ] Replace raw text glyphs with consistent icon approach; keep palette (ink `#172033`, primary `#3b5bfd`, bg `#f5f7fb`, muted `#667085`).
- [ ] Loading/error/empty states everywhere; pull-to-refresh; safe-area + keyboard handling; accessibility labels.

### Module F — Test-Case Log (continuous, required format)
- [x] `docs/TEST_CASE_LOG.md` scaffolded in required format: `Test Case No | Test Case | Expected Outcome | Actual Result`.
- [ ] Fill rows for each implemented module; mark ✅ Pass / ⏳ Pending as work progresses.

### Module G — Backend `/api/v1` Expansion (parity enabler — the big one)
All new controllers inherit `Api::V1::BaseController`; reuse existing models/services/policies; same helpers/error shapes/pagination.

**Priority 1 (needed by tab screens):**
- [ ] `PUT /auth/profile`, `POST /auth/change_password`, `POST /auth/forgot_password`.
- [ ] `GET /home/stats` (classes today, assignments due, notes count, today schedule windows).
- [ ] Assignments: `GET /assignments`, `GET /assignments/:id`, `POST /assignments/:id/submissions` or `POST /assignments/:id/submit`.
- [ ] Schedules: `GET /schedules`, `GET /schedules/:id`, `POST /schedules/:id/enroll`, `DELETE /schedules/:id/enroll`.
- [ ] Messages: `GET /messages/conversations`, `GET /messages/:id`, `POST /messages`, `POST /messages/:id/mark_as_read`, `GET /messages/search_users`.
- [ ] Notifications: `GET /notifications`, `GET /notifications/unread_count`, `POST /notifications/:id/mark_as_read`, `POST /notifications/mark_all_as_read`.
- [ ] Folders: `resources :folders` (index/create/update/destroy).
- [ ] Announcements: `GET /announcements`, `GET /announcements/:id`.

**Priority 2 (secondary features):**
- [ ] Quizzes: `GET /quizzes`, `GET /quizzes/:id`, `POST /quizzes/:id/submit`, `GET /quizzes/:id/results`.
- [ ] Discussions: `GET /discussions`, `GET /discussions/:id`, `POST /discussions/:id/replies` (+ like).
- [ ] Search: `GET /search?q=` (+ results/suggestions).
- [ ] Enrollments: `GET /enrollments`, `POST /enrollments`, `DELETE /enrollments/:id`, `GET /enrollments/capacity/:schedule_id`.
- [ ] Attendance self-checkin: `GET /attendance_lists`, `POST /attendance_records` (code).

**Admin namespace (`/api/v1/admin/*`, role-gated):**
- [ ] `GET /admin/dashboard` (stats), `resources :users` (index/update/change_role/blacklist), `resources :departments` (CRUD/toggle_active), `resources :courses` (CRUD/toggle_active), `resources :schedules` (index/approve/cancel), `resources :announcements` (CRUD/publish/unpublish).

---

## Execution Order
A (baseline tests + tsc fixes) → B (services + types) → G (backend endpoints) → C (RBAC + admin) → D (wire screens) → E (UI polish) → F (update log) → jest/tsc green → **commit + push + EAS preview rebuild** → re-verify.

## Definition of Done (checklist)
- [ ] All 7 tabs + notifications render live data with loading/empty/error states (no static placeholders).
- [ ] Admin role sees the active admin panel; student/teacher never see admin tabs; backend rejects non-admin calls.
- [ ] Every mobile API call maps to a real `/api/v1` endpoint with the documented response shape.
- [ ] `npx jest` all green; `npx tsc --noEmit` clean.
- [ ] `docs/TEST_CASE_LOG.md` fully recorded (every row resolved Pass; no ⏳ at ship time).
- [ ] Branch pushed; EAS preview APK rebuilt and installable.