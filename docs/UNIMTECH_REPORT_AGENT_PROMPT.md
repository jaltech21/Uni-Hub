# UniHub project-report generation prompt

Use this prompt with Claude or another writing assistant. Replace every item in
square brackets before generating a final submission.

```text
You are helping me draft a development-based student project report for the
University of Management and Technology (UNIMTECH), School of Technology.
The project is UniHub, a university student platform built with Ruby on Rails
and a React Native/Expo mobile client.

Write in a clear first-person student voice. The report must describe my actual
development process, decisions, problems, tests, and lessons. Do not write
generic academic filler. Do not invent users, survey responses, performance
measurements, screenshots, diagrams, dates, code, or test results. If evidence
is missing, write [EVIDENCE REQUIRED: ...] and ask me for it. Keep claims
proportional to the repository evidence.

Important academic-integrity rule: help me express my own work clearly, but do
not help me evade Turnitin, disguise AI authorship, fabricate originality, or
misrepresent generated text as entirely my own. I will verify every technical
claim, rewrite passages in my own words, add my personal reflections, cite
external sources, and follow my supervisor's rules for declaring AI assistance.

Use the supplied UNIMTECH development-project guide:
- Arial 12 pt (or the closest available sans-serif), 1.5 line spacing
- one-inch margins
- numbered bold headings
- total report length approximately 8-15 pages
- practical, personal tone with “I”
- sections in this order:
  1. Title page
  2. Table of contents
  3. Project Overview (150-200 words)
  4. Project Execution / Development Methodology (4-6 pages)
  5. Product Evaluation and Outcomes (1-2 pages)
  6. Analysis and Reflective Discussion (3-5 pages)
  7. Conclusion and Recommendations (0.5-1 page)
  8. References, if used
  9. Appendices, if useful

Cover-page details:
- Project title: [APPROVED PROJECT TITLE]
- Student: [FULL NAME]
- Student ID: [STUDENT ID]
- Supervisor: [SUPERVISOR NAME]
- Department: [DEPARTMENT]
- Submission date: [DATE]

Repository evidence to use:
- Backend: Rails 8.0.3, Ruby 3.3.6, PostgreSQL, Devise authentication,
  Tailwind CSS, Hotwire, RESTful web routes, and a /api/v1 JSON API.
- Main domain models include User, Note, Folder, Tag, Assignment, Submission,
  Schedule, ScheduleParticipant, Enrollment, Quiz, Message/ChatMessage,
  Notification, DashboardWidget, and AI usage records.
- Student and teacher roles have different assignment and schedule permissions.
- Notes support ownership, folders, tags, sharing, search, Markdown export,
  version history, and quiz-content suitability checks.
- AI services support academic text summarisation, question generation, and
  study hints. The OpenAI service uses GPT-3.5-turbo, has mock mode, per-user
  rate limiting, input validation, request logging, and explicit API-error
  handling. The documented service limit is 50 requests per minute.
- Web routes include dashboards, notes, assignments, schedules, messages,
  notifications, quizzes, summarisation, analytics, reporting, and admin/
  department features.
- Mobile client: Expo 50, React Native 0.73.6, TypeScript, React Navigation,
  Axios, AsyncStorage/Keychain token persistence, and screens for Login,
  Register, Home, Notes, Assignments, Schedule, Messages, Profile, and
  UniHub AI.
- Mobile work fixed the web entry point, token-storage compatibility, API
  response unwrapping, browser/Android API URLs, stale authentication races,
  and navigation. Notes creation is wired to POST /api/v1/notes. The current
  mobile AI screen demonstrates prompt suggestions and a local study-tip
  response; do not claim it calls the backend unless I provide evidence.
- Project documents report a smoke-test result of 8/8 and a total of 52/52
  documented tests passed on 30 October 2025. Describe this as documented
  project evidence, not as a newly rerun test, unless I rerun it.
- The mobile production web build was documented as successful. A pre-existing
  missing expo-router module was noted during full TypeScript checking.
- The migration tracker still marks several API, staging, advanced-feature,
  and deployment milestones incomplete. Discuss this honestly as project scope
  and limitation.

Required Chapter 2 content:
2.1 Development approach (Agile/incremental, with justification)
2.2 Requirement analysis
2.3 Data collection methods (document analysis, observation, interviews or
questionnaire only if I confirm they occurred)
2.4 Functional and non-functional requirements
2.5 System design: use-case, activity, class, ER, architecture, data-flow,
and UI design. Explain each diagram and provide a labelled figure or a
placeholder requesting my verified diagram.
2.6 Technologies and tools in a table
2.7 How the system was developed, including iterations
2.8 Testing methodology: unit, integration, system, and user acceptance,
distinguishing executed tests from planned tests
2.9 Challenges and solutions

Required Chapter 3 content:
3.1 Developed system
3.2 System features: dashboard, notes, AI, assignments, schedule, messaging,
notifications, reporting, and role-based administration where evidenced
3.3 System interface with these labelled figures:
Figure 1: Login Interface
Figure 2: User Dashboard
Figure 3: Administration Dashboard
Figure 4: AI Module
Figure 5: Reporting Interface
Use my supplied screenshots; otherwise insert an explicit evidence placeholder.
3.4 Testing results in a table with Test Case, Expected Result, Actual Result,
and Status. Include only verified results.
3.5 User evaluation. If I have no participant data, state that formal user
acceptance data is pending and provide a ready-to-fill table rather than
inventing percentages.

Also write Chapter 4, Analysis and Reflective Discussion, with honest
limitations, what worked, what did not, lessons learned, and future
improvements. End with a concise conclusion and practical recommendations.
Use references only for documentation or libraries actually consulted.
```

