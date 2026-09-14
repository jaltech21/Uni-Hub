# Phase 4: Technical Evidence Verification

This matrix verifies the main technical claims in the report against the
repository. It does not edit Chapters 1–3 or apply final formatting.

## Evidence classification

- **Implemented:** directly supported by current source code.
- **Documented:** supported by project documentation, but not independently
  rerun during this phase.
- **Partial:** some related code exists, but the complete end-to-end claim is
  not supported.
- **Planned:** listed in the migration plan but not evidenced as complete.
- **Needs evidence:** requires a test log, screenshot, schema output, or user
  record before it can be claimed as a result.

## Verified claims

| Report claim | Classification | Repository evidence | Report action |
|---|---|---|---|
| Rails application and `/api/v1` API exist | Implemented | `config/routes.rb` contains the API namespace and authentication/notes routes | Keep |
| API login, registration, refresh, current-user, and logout routes exist | Implemented | `config/routes.rb` lines 7–15 | Keep, but distinguish routes from successful current testing |
| Web notes provide CRUD routes | Implemented | `resources :notes` and member sharing/export/version routes | Keep |
| Notes support ownership, folders, tags, sharing, search, export, and versioning | Implemented | `app/models/note.rb` associations, scopes, search, sharing, Markdown, and version methods | Keep |
| User has academic and communication associations | Implemented | `app/models/user.rb` associations for assignments, submissions, schedules, enrolments, quizzes, messages, notifications, analytics, and notes | Keep |
| Student/teacher role rules exist | Implemented | `User#student?`, `User#teacher?`, role validation, and documented controller authorization | Keep, with test evidence labelled separately |
| AI supports summarisation, questions, and study hints | Implemented | `app/services/open_ai_service.rb` defines all three methods | Keep |
| AI uses GPT-3.5-turbo when configured | Implemented | OpenAI completion calls specify `gpt-3.5-turbo` | Keep |
| AI supports mock mode and rate limiting | Implemented | Environment-controlled mock mode and `RATE_LIMIT = 50` with rate limiter | Keep |
| AI validates inputs and logs successes/failures | Implemented | Blank/length validation and `log_ai_request`, `log_ai_success`, `log_ai_failure` calls | Keep |
| Mobile uses Expo, React Native, TypeScript, Axios, and React Navigation | Implemented | `mobile/package.json`, navigation, screens, and service imports | Keep |
| Mobile authentication uses platform-aware storage | Implemented | `mobile/app/services/api.ts` uses AsyncStorage on web and native Keychain with fallback logic | Keep, but avoid calling AsyncStorage a secure native store |
| Mobile root navigator switches auth and app flows | Implemented | `RootNavigator.tsx` renders AuthStack or AppTabs based on `user` | Keep |
| Mobile note listing and creation are wired to the API | Implemented | `NotesScreen.tsx` calls `GET /notes` and `POST /notes` | Keep, pending current integration test evidence |
| Mobile AI screen exists | Implemented | `AIAssistantScreen.tsx` is registered in the tab navigator | Keep |
| Mobile AI currently returns a local study tip | Implemented | Screen sets `submittedQuestion` and renders a local response; no AI API call is present | Keep the report's limitation statement |
| Web routes include assignments, schedules, messages, notifications, quizzes, analytics, and reports | Implemented | Matching resources and controllers are present in the Rails application | Keep, distinguishing web routes from mobile API parity |

## Claims supported only by project documentation

| Report claim | Classification | Evidence | Required wording |
|---|---|---|---|
| 8/8 smoke tests passed | Documented | `Uni-Hub/TESTING_REPORT.md` | “The project testing report records…” |
| 52/52 documented tests passed | Documented | `Uni-Hub/TESTING_REPORT.md` | Do not present as a newly executed result |
| Testing date was 30 October 2025 | Documented | `TESTING_REPORT.md` | Retain only as the report's recorded date |
| Mobile production web build succeeded | Documented | Prior implementation record/checkpoint | Add command and current build log if available |
| Full TypeScript check reports missing `expo-router` | Documented | Prior implementation record/checkpoint | Retain as an open issue until rerun |

## Partial or planned claims

| Report claim | Classification | Finding | Required wording |
|---|---|---|---|
| Mobile feature parity with the web application | Partial | Mobile screens exist for several areas, but the migration tracker leaves API and MVP milestones open | State that parity is incomplete |
| Mobile assignments, schedules, messages, and notifications are fully functional | Planned/partial | UI screens exist, but current mobile API routes expose authentication and notes only | Do not claim end-to-end mobile functionality |
| Mobile AI calls the backend AI provider | Not supported | Current mobile assistant renders a local study-tip response and has no AI API request | State that server integration is pending |
| Formal user acceptance was completed | Needs evidence | No participant records or results are present | Keep as pending |
| Performance metrics were measured | Needs evidence | The testing report contains status claims but no reproducible timing dataset in the reviewed evidence | Do not claim measured load time or latency |
| Class and ER diagrams reflect the database schema | Needs evidence | The report describes associations but no schema-verified diagram is currently included | Add diagram only after schema review |

## Security and privacy verification

The report correctly avoids listing member passwords or credentials. The
repository evidence supports protected API-key configuration, Devise-based
authentication, role validation, and note ownership methods. A formal security
audit, penetration test, or compliance certification is not evidenced and must
not be claimed.

## Evidence still required from the project owner

1. Approved project title and final cover-page details.
2. Current test command output for the stated test results.
3. A clean final login screenshot and dashboard screenshot.
4. Verified use-case and class/ER diagrams.
5. Any real user-evaluation records.
6. Confirmed AI mode for any screenshot: mock or live.
7. Current performance measurements, if the supervisor requires them.

## Phase 4 completion record

- [x] Verified backend routes and mobile routes
- [x] Verified model and service claims
- [x] Verified mobile navigation and note integration claims
- [x] Distinguished implemented, documented, partial, planned, and unsupported claims
- [x] Checked testing and user-evaluation claims for evidence status
- [x] Checked credential and security statements
- [x] Recorded evidence still required
- [ ] Phase 5 image/formatting review — not started
