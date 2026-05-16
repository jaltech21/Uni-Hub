# Phase 0.2: Design API Schema

**Target Completion:** May 17, 2026  
**Status:** 📋 In Progress (Schema Design)  
**Effort:** 1–2 days  
**Owner:** Backend Lead

---

## Executive Summary

This document specifies the complete JSON API schema for the UniHub mobile app (`/api/v1/`). All endpoints follow RESTful conventions with token-based authentication (JWT via `devise_token_auth`).

**Base URL (Development):** `http://localhost:3000/api/v1`  
**Base URL (Staging):** `https://staging.unihub.app/api/v1`  
**Base URL (Production):** `https://api.unihub.app/api/v1`

---

## 1. Authentication Endpoints

### 1.1 POST /auth/login

**Purpose:** Authenticate user and receive access + refresh tokens

**Request:**
```json
{
  "email": "student@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "student@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "role": "student",
      "department_id": 5,
      "profile_picture_url": "https://cdn.example.com/avatars/1.jpg"
    },
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "refresh_token_xyz..."
  }
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "status": 401,
    "message": "Invalid email or password",
    "code": "AUTH_FAILED"
  }
}
```

**Headers Required:** None (public endpoint)  
**Rate Limit:** 5 attempts per 15 minutes per IP

---

### 1.2 POST /auth/register

**Purpose:** Create new user account

**Request:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@example.com",
  "password": "SecurePassword123!",
  "password_confirmation": "SecurePassword123!",
  "role": "student",
  "department_id": 5
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "john.doe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "role": "student",
      "department_id": 5,
      "profile_picture_url": null
    },
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "refresh_token_xyz..."
  }
}
```

**Validation Errors (422):**
```json
{
  "success": false,
  "error": {
    "status": 422,
    "message": "Validation failed",
    "errors": {
      "email": ["has already been taken"],
      "password": ["is too short (minimum is 8 characters)"]
    }
  }
}
```

**Headers Required:** None (public endpoint)

---

### 1.3 POST /auth/refresh

**Purpose:** Refresh expired access token using refresh token

**Request Headers:**
```
Authorization: Bearer {{refresh_token}}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "refresh_token_abc..."
  }
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "status": 401,
    "message": "Refresh token expired or invalid",
    "code": "REFRESH_FAILED"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <refresh_token>`

---

### 1.4 GET /auth/current_user

**Purpose:** Get authenticated user's profile

**Request Headers:**
```
Authorization: Bearer {{access_token}}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "student@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "role": "student",
    "department_id": 5,
    "department_name": "Computer Science",
    "profile_picture_url": "https://cdn.example.com/avatars/1.jpg",
    "created_at": "2026-01-15T10:00:00Z",
    "updated_at": "2026-05-16T14:30:00Z"
  }
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "status": 401,
    "message": "Unauthorized",
    "code": "TOKEN_INVALID"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 1.5 POST /auth/logout

**Purpose:** Revoke session/tokens

**Request:** Empty body

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 2. Notes Endpoints

### 2.1 GET /notes

**Purpose:** List user's notes with pagination

**Query Parameters:**
```
page=1&per_page=20&folder_id=5&tag=important&search=notes
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "React Basics",
      "content": "React is a JavaScript library...",
      "folder_id": 5,
      "folder_name": "Web Development",
      "tags": [
        { "id": 1, "name": "react" },
        { "id": 2, "name": "javascript" }
      ],
      "created_at": "2026-05-10T09:00:00Z",
      "updated_at": "2026-05-16T14:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 2.2 GET /notes/:id

**Purpose:** Get single note details

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "React Basics",
    "content": "React is a JavaScript library for building user interfaces...",
    "folder_id": 5,
    "folder_name": "Web Development",
    "tags": [
      { "id": 1, "name": "react" },
      { "id": 2, "name": "javascript" }
    ],
    "shared_with": [
      {
        "id": 3,
        "name": "Jane Smith",
        "email": "jane@example.com"
      }
    ],
    "created_at": "2026-05-10T09:00:00Z",
    "updated_at": "2026-05-16T14:00:00Z"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 2.3 POST /notes

**Purpose:** Create new note

**Request:**
```json
{
  "title": "React Hooks",
  "content": "useState, useEffect, useContext...",
  "folder_id": 5,
  "tags": ["react", "hooks"]
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": 42,
    "title": "React Hooks",
    "content": "useState, useEffect, useContext...",
    "folder_id": 5,
    "tags": [
      { "id": 1, "name": "react" },
      { "id": 3, "name": "hooks" }
    ],
    "created_at": "2026-05-16T15:00:00Z",
    "updated_at": "2026-05-16T15:00:00Z"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

---

### 2.4 PUT /notes/:id

**Purpose:** Update note

**Request:**
```json
{
  "title": "React Hooks (Updated)",
  "content": "useState, useEffect, useContext, custom hooks...",
  "tags": ["react", "hooks", "advanced"]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 42,
    "title": "React Hooks (Updated)",
    "content": "useState, useEffect, useContext, custom hooks...",
    "tags": [
      { "id": 1, "name": "react" },
      { "id": 3, "name": "hooks" },
      { "id": 4, "name": "advanced" }
    ],
    "updated_at": "2026-05-16T15:30:00Z"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 2.5 DELETE /notes/:id

**Purpose:** Delete note

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Note deleted successfully"
}
```

**Error (404 Not Found):**
```json
{
  "success": false,
  "error": {
    "status": 404,
    "message": "Note not found"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 3. Summarization Endpoints

### 3.1 POST /summarizations/create

**Purpose:** Generate summary of text using AI

**Request:**
```json
{
  "text": "Long text content to summarize...",
  "length": "medium"
}
```

**Parameters:**
- `length`: `short` | `medium` | `long` (default: `medium`)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "original_text_length": 2500,
    "summary": "Concise summary of the original text...",
    "summary_length": 350,
    "compression_ratio": 14.0,
    "processing_time_ms": 1250
  }
}
```

**Error (422 Unprocessable Entity):**
```json
{
  "success": false,
  "error": {
    "status": 422,
    "message": "Text must be at least 100 characters",
    "code": "TEXT_TOO_SHORT"
  }
}
```

**Error (503 Service Unavailable):**
```json
{
  "success": false,
  "error": {
    "status": 503,
    "message": "AI service temporarily unavailable",
    "code": "AI_SERVICE_ERROR"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

**Rate Limit:** 10 requests per hour per user

---

## 4. Quiz Endpoints

### 4.1 POST /quizzes/generate

**Purpose:** Generate quiz from note using AI (async job)

**Request:**
```json
{
  "note_id": 42,
  "num_questions": 5,
  "difficulty": "medium"
}
```

**Parameters:**
- `num_questions`: 3-20 (default: 5)
- `difficulty`: `easy` | `medium` | `hard` (default: `medium`)

**Response (202 Accepted - Async Job Started):**
```json
{
  "success": true,
  "data": {
    "job_id": "job_uuid_12345",
    "status": "queued",
    "message": "Quiz generation started. Check status with job_id.",
    "estimated_wait_seconds": 30
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 4.2 GET /quizzes/generation_status/:job_id

**Purpose:** Check async quiz generation job status

**Response (200 OK - Job In Progress):**
```json
{
  "success": true,
  "data": {
    "job_id": "job_uuid_12345",
    "status": "processing",
    "progress_percent": 65
  }
}
```

**Response (200 OK - Job Complete):**
```json
{
  "success": true,
  "data": {
    "job_id": "job_uuid_12345",
    "status": "completed",
    "quiz_id": 99,
    "quiz_title": "React Basics Quiz",
    "num_questions": 5
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 4.3 GET /quizzes

**Purpose:** List user's quizzes

**Query Parameters:**
```
page=1&per_page=20&status=published&difficulty=medium
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 99,
      "title": "React Basics Quiz",
      "note_id": 42,
      "status": "published",
      "difficulty": "medium",
      "total_questions": 5,
      "time_limit_minutes": null,
      "average_score": 78.5,
      "attempts_count": 12,
      "created_at": "2026-05-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 25
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 4.4 GET /quizzes/:id

**Purpose:** Get quiz details with all questions

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 99,
    "title": "React Basics Quiz",
    "note_id": 42,
    "status": "published",
    "difficulty": "medium",
    "total_questions": 5,
    "time_limit_minutes": 30,
    "questions": [
      {
        "id": 1,
        "quiz_id": 99,
        "question_text": "What is React?",
        "question_type": "multiple_choice",
        "options": [
          "A JavaScript library",
          "A CSS framework",
          "A backend framework",
          "A database tool"
        ],
        "correct_answer_index": 0,
        "explanation": "React is a JavaScript library for building user interfaces."
      }
    ],
    "created_at": "2026-05-15T10:00:00Z"
  }
}
```

**Note:** `correct_answer_index` should only be included if user is quiz owner/teacher or after attempting.

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 4.5 POST /quizzes/:id/attempts

**Purpose:** Submit quiz attempt

**Request:**
```json
{
  "answers": [
    { "question_id": 1, "answer_index": 0 },
    { "question_id": 2, "answer_index": 2 },
    { "question_id": 3, "answer_index": 1 }
  ]
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "attempt_id": 555,
    "quiz_id": 99,
    "user_id": 1,
    "score": 80,
    "total_points": 100,
    "percentage": 80.0,
    "completed_at": "2026-05-16T15:45:00Z",
    "results": [
      {
        "question_id": 1,
        "user_answer_index": 0,
        "correct_answer_index": 0,
        "is_correct": true,
        "explanation": "Correct! React is indeed a JavaScript library."
      }
    ]
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 5. Assignments & Submissions Endpoints

### 5.1 GET /assignments

**Purpose:** List assignments (students see assigned, teachers see created)

**Query Parameters:**
```
page=1&per_page=20&status=active&due_date_sort=asc
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 10,
      "title": "Build a React App",
      "description": "Create a todo list app with React and Context API",
      "teacher_id": 2,
      "teacher_name": "Prof. Smith",
      "subject": "Web Development",
      "due_date": "2026-05-30T23:59:59Z",
      "status": "active",
      "total_points": 100,
      "submitted_count": 5,
      "total_students": 20,
      "user_submission_status": "submitted"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 15
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 5.2 GET /assignments/:id

**Purpose:** Get assignment details

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 10,
    "title": "Build a React App",
    "description": "Create a todo list app with React and Context API",
    "teacher_id": 2,
    "teacher_name": "Prof. Smith",
    "subject": "Web Development",
    "created_date": "2026-05-10T10:00:00Z",
    "due_date": "2026-05-30T23:59:59Z",
    "status": "active",
    "total_points": 100,
    "rubric": [
      { "criteria": "Functionality", "points": 40 },
      { "criteria": "Code Quality", "points": 30 },
      { "criteria": "UI/UX", "points": 30 }
    ],
    "user_submission": {
      "id": 50,
      "submitted_at": "2026-05-28T14:30:00Z",
      "content": "https://github.com/student/todo-app",
      "status": "submitted",
      "score": null,
      "feedback": null
    }
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 5.3 POST /submissions

**Purpose:** Submit assignment (student)

**Request:**
```json
{
  "assignment_id": 10,
  "content": "https://github.com/student/todo-app",
  "notes": "Completed with bonus features"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": 50,
    "assignment_id": 10,
    "user_id": 1,
    "content": "https://github.com/student/todo-app",
    "notes": "Completed with bonus features",
    "submitted_at": "2026-05-28T14:30:00Z",
    "status": "submitted"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 6. Schedules & Attendance Endpoints

### 6.1 GET /schedules

**Purpose:** List user's schedules/timetable

**Query Parameters:**
```
page=1&per_page=50&department_id=5
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 15,
      "title": "Web Development Lecture",
      "instructor_id": 2,
      "instructor_name": "Prof. Smith",
      "department_id": 5,
      "room": "Lab 201",
      "start_time": "2026-05-20T10:00:00Z",
      "end_time": "2026-05-20T11:30:00Z",
      "day_of_week": "Monday",
      "recurrence": "weekly",
      "participant_count": 30
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 8
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 6.2 GET /attendance_lists/:id

**Purpose:** Get attendance for a schedule

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 150,
    "schedule_id": 15,
    "date": "2026-05-20",
    "total_students": 30,
    "present": 28,
    "absent": 2,
    "records": [
      {
        "id": 1500,
        "user_id": 1,
        "user_name": "John Doe",
        "status": "present",
        "marked_at": "2026-05-20T10:05:00Z"
      }
    ]
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`
- (Teachers only)

---

## 7. Messages & Communication Endpoints

### 7.1 GET /messages/conversations

**Purpose:** List user's message conversations

**Query Parameters:**
```
page=1&per_page=20
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "conversation_id": 1,
      "other_user_id": 3,
      "other_user_name": "Jane Smith",
      "other_user_avatar": "https://cdn.example.com/avatars/3.jpg",
      "last_message": "See you in class tomorrow!",
      "last_message_time": "2026-05-16T14:30:00Z",
      "unread_count": 2
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 15
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 7.2 GET /messages/:user_id

**Purpose:** Get message history with specific user

**Query Parameters:**
```
page=1&per_page=50
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1001,
      "sender_id": 1,
      "recipient_id": 3,
      "message": "Hi Jane, how are you?",
      "sent_at": "2026-05-16T10:00:00Z",
      "read_at": "2026-05-16T10:05:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 42
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 7.3 POST /messages

**Purpose:** Send message to user

**Request:**
```json
{
  "recipient_id": 3,
  "message": "Hi Jane, how are you?"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": 1001,
    "sender_id": 1,
    "recipient_id": 3,
    "message": "Hi Jane, how are you?",
    "sent_at": "2026-05-16T10:00:00Z"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 8. Device/Push Notification Endpoints

### 8.1 POST /devices/register

**Purpose:** Register device for push notifications

**Request:**
```json
{
  "device_token": "fcm_token_xyz...",
  "platform": "android",
  "device_model": "Samsung Galaxy S21",
  "os_version": "12.0"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "device_token": "fcm_token_xyz...",
    "platform": "android",
    "registered_at": "2026-05-16T15:00:00Z"
  }
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

### 8.2 DELETE /devices/:id

**Purpose:** Unregister device

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device unregistered"
}
```

**Headers Required:**
- `Authorization: Bearer <access_token>`

---

## 9. Error Handling & Status Codes

### Standard HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Successful GET/PUT |
| 201 | Created | Successful POST |
| 202 | Accepted | Async job started |
| 400 | Bad Request | Invalid parameters |
| 401 | Unauthorized | Missing/invalid token |
| 403 | Forbidden | User not authorized for resource |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Server Error | Internal server error |
| 503 | Service Unavailable | AI service down |

### Standard Error Response Format

```json
{
  "success": false,
  "error": {
    "status": 422,
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "errors": {
      "title": ["can't be blank"],
      "content": ["is too short (minimum is 10 characters)"]
    }
  }
}
```

---

## 10. Authentication & Authorization

### Token Headers

All authenticated endpoints require:
```
Authorization: Bearer <access_token>
```

### Token Lifecycle

- **Access Token:** Valid for 1 hour
- **Refresh Token:** Valid for 30 days
- **Token Refresh:** Auto-triggered by mobile app when access token expires
- **Token Storage:** Secure device keychain (iOS) / Keystore (Android)

---

## 11. Rate Limiting

| Endpoint Category | Limit |
|------------------|-------|
| Authentication (login/register) | 5 requests / 15 minutes per IP |
| Summarization | 10 requests / hour per user |
| Quiz generation | 5 requests / hour per user |
| General API | 100 requests / minute per user |

**Headers Returned:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1684335600
```

---

## 12. Pagination

### Query Parameters

```
page=1&per_page=20
```

### Response Format

```json
{
  "success": true,
  "data": [...],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 250,
    "total_pages": 13
  }
}
```

- **Default per_page:** 20
- **Max per_page:** 100

---

## 13. Sorting & Filtering

### Common Query Patterns

```
GET /notes?sort=created_at:desc&created_after=2026-05-01&tags=react
GET /quizzes?difficulty=hard&sort=average_score:desc
GET /assignments?due_date_sort=asc&status=active
GET /schedules?department_id=5&day_of_week=monday
```

### Sort Format: `field:direction`

- Direction: `asc` | `desc`

---

## 14. File Uploads (Future Phase)

### POST /file_uploads

**Multipart Form Data:**
```
POST /file_uploads
Content-Type: multipart/form-data

file: <binary_file_data>
file_type: assignment_submission
metadata[assignment_id]: 10
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "file_id": "uuid_12345",
    "file_url": "https://cdn.example.com/uploads/uuid_12345",
    "file_name": "project.zip",
    "file_size": 2048576,
    "uploaded_at": "2026-05-16T15:00:00Z"
  }
}
```

---

## 15. Next Steps

1. **Backend Implementation:** Create API controllers in `/api/v1/` namespace
2. **Serializers:** Implement JSON serialization for all models
3. **Tests:** Write RSpec tests for all endpoints
4. **Staging Deployment:** Deploy to staging environment
5. **Mobile Integration:** Begin Phase 1.6 (API integration in React Native)

---

## Appendix: OpenAPI/Swagger File

Generate OpenAPI 3.0.0 spec at: `/swagger.yaml` or via `http://localhost:3000/api-docs`

(To be implemented with `rswag` gem for documentation)

