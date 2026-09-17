# UniHub Mobile — Test Case Log

Format: **Test Case No | Test Case | Expected Outcome | Actual Result**
Legend: ✅ Pass · ⏳ Pending · ❌ Fail (+ note)

## Module A — Test Infrastructure & Baseline

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-001 | Jest suite boots (jest-expo + nativewind transform) | Tests run without transform errors | ✅ Pass (8/8, LoginScreen.test.tsx) |
| TC-002 | LoginScreen renders (onboarding + login form) | Carousel + email/password fields render | ✅ Pass |
| TC-003 | Login with valid credentials calls `login`, no error shown | `login` invoked; error absent | ✅ Pass |
| TC-004 | Login with invalid credentials shows error | Error message rendered | ✅ Pass |
| TC-005 | Register navigation link present | Link navigates to Register | ✅ Pass |
| TC-006 | `npx tsc --noEmit` passes | Zero TypeScript errors | ✅ Pass |
| TC-007 | Vestigial expo-router stubs removed (`app/_layout.tsx`, `app/index.tsx`) | No `expo-router` import; entry is `index.js` | ✅ Pass (files deleted) |
| TC-008 | Duplicate `jest.setTimeout(120000)` removed | Single occurrence; tests pass | ✅ Pass |

## Module B — API Service Layer

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-009 | AuthService.logout uses `DELETE /auth/logout` with Bearer header | Correct verb + token; tokens cleared | ✅ Pass (already fixed) |
| TC-010 | Dead endpoints removed/guarded (`/auth/profile`, `/auth/change_password`, `/auth/forgot_password`) | No UI path calls endpooints that don't exist | ⏳ Pending |
| TC-011 | New services compile (Assignment/Schedule/Message/Notification/Folder/Quiz/Announcement/Admin) | `tsc` clean with new types | ⏳ Pending |
| TC-012 | Services map to correct `/api/v1` routes | Each method hits the documented route | ⏳ Pending |

## Module C — Role-Based Access + Admin Panel

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-013 | Student role sees only student tabs (no Admin) | Admin tabs absent for student | ⏳ Pending |
| TC-014 | Teacher role sees teacher tabs (no Admin) | Admin tabs absent for teacher | ⏳ Pending |
| TC-015 | Admin role sees Admin Dashboard + admin tabs | Admin stack reachable | ⏳ Pending |
| TC-016 | Non-admin calling `/admin/*` gets 403 | Backend rejects with FORBIDDEN | ⏳ Pending |
| TC-017 | AdminUsersScreen lists users, changes role, blacklists | CRUD persists via `/admin/users` | ⏳ Pending |
| TC-018 | AdminDepartmentsScreen CRUD + toggle active | Persists via `/admin/departments` | ⏳ Pending |
| TC-019 | AdminCoursesScreen CRUD + toggle active | Persists via `/admin/courses` | ⏳ Pending |
| TC-020 | AdminSchedulesScreen approve/cancel | Status updates persist | ⏳ Pending |
| TC-021 | AdminAnnouncementsScreen CRUD + publish/unpublish | Persists via `/admin/announcements` | ⏳ Pending |

## Module D — Feature-Parity Screens

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-022 | HomeScreen shows real stats (classes today / due / notes) + schedule | No hardcoded zeros; data from API | ⏳ Pending |
| TC-023 | AssignmentsScreen lists with status + submit flow | List + submit persist | ⏳ Pending |
| TC-024 | ScheduleScreen day view + enroll/unenroll | Real events; enroll works | ⏳ Pending |
| TC-025 | MessagesScreen conversations + thread + compose + mark-as-read | Threads load; send works | ⏳ Pending |
| TC-026 | Notifications badge + list + mark-all-read | Badge reflects `unread_count` | ⏳ Pending |
| TC-027 | Profile edit + change password (once backend lands) | Persists via API | ⏳ Pending |
| TC-028 | Notes + AI screens keep working after refactor | List/create + summarize pass | ⏳ Pending |

## Module E — UI/UX Cleanup

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-029 | Loading/empty/error states on all data screens | No blank screens | ⏳ Pending |
| TC-030 | Pull-to-refresh on data screens | Re-fetches on pull | ⏳ Pending |
| TC-031 | Shared component kit used (ScreenHeader, EmptyState, etc.) | Consistent look | ⏳ Pending |
| TC-032 | Accessibility labels on icon buttons | Labels present | ⏳ Pending |

## Module G — Backend `/api/v1` Expansion

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-033 | `GET /home/stats` returns classes today, due, notes, upcoming | 200 typed payload | ⏳ Pending |
| TC-034 | Assignment endpoints (list/detail/submit) | 200 list/detail; submit creates | ⏳ Pending |
| TC-035 | Schedule endpoints (list/enroll/unenroll) | 200 list; enroll adds; unenroll removes | ⏳ Pending |
| TC-036 | Message endpoints (conversations/thread/send/mark_read/search) | 200 for all verbs | ⏳ Pending |
| TC-037 | Notification endpoints (list/unread_count/mark_all) | 200 + accurate counts | ⏳ Pending |
| TC-038 | Folder CRUD endpoints | 200 CRUD | ⏳ Pending |
| TC-039 | Announcement list/detail | 200 index/show | ⏳ Pending |
| TC-040 | Auth profile endpoints (update/change_password/forgot_password) | 200 / 422 validations | ⏳ Pending |
| TC-041 | Admin endpoints role-gated (users/departments/courses/schedules/announcements/dashboard) | 200 for admin; 403 otherwise | ⏳ Pending |
| TC-042 | Quiz endpoints (list/submit/results) | 200 list/submit/results | ⏳ Pending |
| TC-043 | Search endpoint returns results + suggestions | 200 with matches | ⏳ Pending |

## Final Regression

| Test Case No | Test Case | Expected Outcome | Actual Result |
|---|---|---|---|
| TC-044 | Full `npx jest` pass | All suites green | ⏳ Pending |
| TC-045 | `npx tsc --noEmit` clean | 0 errors | ⏳ Pending |
| TC-046 | EAS preview APK builds + installs | Build succeeds via eas-cli | ⏳ Pending |