# Uni-Hub Week 2 API Documentation

## Department Reports API

### Base URL
All endpoints are relative to `/departments/:department_id/reports/`

### Authentication
All endpoints require user authentication via Devise session. Users must be members of the department they're accessing.

### Authorization
- Users can only access reports for departments they belong to
- Admin users have access to all department reports
- Teachers and students have read-only access to their department reports

---

## Endpoints

### 1. Generate Basic Report

**GET** `/departments/:department_id/reports/basic`

Generates a basic overview report with key department metrics.

#### Parameters
- `department_id` (required): Department ID
- `start_date` (optional): Start date for report data (YYYY-MM-DD)
- `end_date` (optional): End date for report data (YYYY-MM-DD)

#### Request Example
```http
GET /departments/1/reports/basic?start_date=2024-01-01&end_date=2024-01-31
Authorization: Session-based authentication
Content-Type: application/json
```

#### Response Example (200 OK)
```json
{
  "status": "success",
  "data": {
    "total_users": 45,
    "active_users": 38,
    "inactive_users": 7,
    "total_content": 156,
    "recent_activity": 23,
    "engagement_rate": 84.4,
    "content_breakdown": {
      "assignments": 45,
      "quizzes": 28,
      "notes": 67,
      "announcements": 16
    },
    "activity_summary": {
      "content_shared": 34,
      "member_changes": 5,
      "recent_logins": 38
    },
    "report_generated_at": "2024-01-15T10:30:00Z",
    "date_range": {
      "start": "2024-01-01",
      "end": "2024-01-31"
    }
  }
}
```

#### Error Responses
- `401 Unauthorized`: User not authenticated
- `403 Forbidden`: User not authorized to access this department
- `404 Not Found`: Department not found
- `422 Unprocessable Entity`: Invalid date parameters

---

### 2. Generate Detailed Report

**GET** `/departments/:department_id/reports/detailed`

Generates a comprehensive detailed analysis report.

#### Parameters
- `department_id` (required): Department ID
- `start_date` (optional): Start date for report data
- `end_date` (optional): End date for report data

#### Response Example (200 OK)
```json
{
  "status": "success",
  "data": {
    "user_statistics": [
      {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
        "role": "teacher",
        "activity_count": 25,
        "last_active": "2024-01-15T08:30:00Z",
        "content_created": 12,
        "engagement_score": 92.5
      },
      {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane@example.com",
        "role": "student",
        "activity_count": 18,
        "last_active": "2024-01-14T15:45:00Z",
        "content_created": 5,
        "engagement_score": 78.3
      }
    ],
    "content_statistics": [
      {
        "type": "Assignment",
        "count": 45,
        "recent_count": 12,
        "avg_engagement": 85.2,
        "top_creators": ["John Doe", "Sarah Wilson"]
      },
      {
        "type": "Quiz",
        "count": 28,
        "recent_count": 8,
        "avg_engagement": 73.8,
        "top_creators": ["John Doe", "Mike Johnson"]
      }
    ],
    "activity_timeline": [
      {
        "date": "2024-01-15",
        "total_activities": 12,
        "content_shared": 5,
        "member_changes": 1,
        "logins": 6
      },
      {
        "date": "2024-01-14",
        "total_activities": 8,
        "content_shared": 3,
        "member_changes": 0,
        "logins": 5
      }
    ],
    "report_generated_at": "2024-01-15T10:30:00Z"
  }
}
```

---

### 3. Generate Summary Report

**GET** `/departments/:department_id/reports/summary`

Generates an executive summary report with key insights and recommendations.

#### Response Example (200 OK)
```json
{
  "status": "success",
  "data": {
    "overview": "The Computer Science department shows strong engagement with 84% active users and increasing content creation trends.",
    "key_metrics": [
      "User engagement: 84.4%",
      "Content creation: +15% this month",
      "Activity trend: Increasing",
      "Most active day: Monday",
      "Peak hours: 10 AM - 2 PM"
    ],
    "insights": [
      "Quiz engagement is lower than assignments",
      "Students are more active in morning hours",
      "Content sharing has increased significantly"
    ],
    "recommendations": [
      "Continue current engagement strategies",
      "Focus on quiz creation training for teachers",
      "Monitor and support inactive users",
      "Consider gamification for quiz participation"
    ],
    "performance_trends": {
      "week_over_week": "+12%",
      "month_over_month": "+23%",
      "quarter_over_quarter": "+18%"
    },
    "report_generated_at": "2024-01-15T10:30:00Z"
  }
}
```

---

### 4. Export Report (CSV)

**GET** `/departments/:department_id/reports/export`

Exports report data in specified format.

#### Parameters
- `department_id` (required): Department ID
- `format` (required): Export format (`csv`, `pdf`, `excel`)
- `report_type` (required): Type of report (`basic`, `detailed`, `summary`)
- `start_date` (optional): Start date for report data
- `end_date` (optional): End date for report data

#### Request Example
```http
GET /departments/1/reports/export?format=csv&report_type=basic&start_date=2024-01-01&end_date=2024-01-31
```

#### Response
- Returns file download with appropriate Content-Type
- CSV: `text/csv`
- PDF: `application/pdf`
- Excel: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`

#### Response Headers
```http
Content-Type: text/csv
Content-Disposition: attachment; filename="department_basic_report_2024-01-15.csv"
```

---

## Department Activity Feed API

### Base URL
All endpoints are relative to `/departments/:department_id/activity/`

---

### 5. Activity Feed Index

**GET** `/departments/:department_id/activity`

Returns the main activity feed page (HTML) or activity data (JSON).

#### Request Headers
- HTML: `Accept: text/html`
- JSON: `Accept: application/json`

#### Parameters
- `page` (optional): Page number for pagination (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 50)

#### JSON Response Example (200 OK)
```json
{
  "activities": [
    {
      "id": "content_sharing_123",
      "type": "content_sharing",
      "title": "Assignment shared: Data Structures Lab",
      "description": "John Doe shared an assignment with the department",
      "user_name": "John Doe",
      "user_id": 1,
      "formatted_time": "2 hours ago",
      "formatted_date": "January 15, 2024",
      "icon": "fas fa-share-alt",
      "color": "text-blue-600",
      "url": "/assignments/45"
    },
    {
      "id": "member_change_456",
      "type": "member_change", 
      "title": "New member joined",
      "description": "Jane Smith joined the Computer Science department",
      "user_name": "Jane Smith",
      "user_id": 2,
      "formatted_time": "4 hours ago",
      "formatted_date": "January 15, 2024",
      "icon": "fas fa-user-plus",
      "color": "text-green-600",
      "url": "/users/2"
    }
  ],
  "has_more": true,
  "current_page": 1,
  "total_pages": 5,
  "total_count": 89,
  "activity_types_summary": {
    "announcements": 12,
    "content_sharing": 25,
    "member_changes": 8,
    "assignments": 28,
    "quizzes": 11,
    "notes": 15
  },
  "most_active_users": [
    {
      "id": 1,
      "name": "John Doe",
      "count": 15,
      "avatar_url": "/avatars/john.jpg"
    },
    {
      "id": 2,
      "name": "Jane Smith", 
      "count": 12,
      "avatar_url": "/avatars/jane.jpg"
    }
  ]
}
```

---

### 6. Filter Activities

**GET** `/departments/:department_id/activity/filter`

Filters activities based on criteria. Returns JSON only.

#### Parameters
- `activity_types[]` (optional): Array of activity types to include
- `user_id` (optional): Filter by specific user
- `date_from` (optional): Start date filter (YYYY-MM-DD)
- `date_to` (optional): End date filter (YYYY-MM-DD)
- `page` (optional): Page number
- `per_page` (optional): Items per page

#### Request Example
```http
GET /departments/1/activity/filter?activity_types[]=content_sharing&activity_types[]=assignments&date_from=2024-01-01&user_id=1&page=1
Accept: application/json
```

#### Response Example (200 OK)
```json
{
  "activities": [
    {
      "id": "content_sharing_789",
      "type": "content_sharing",
      "title": "Quiz shared: Algorithm Basics",
      "description": "John Doe shared a quiz with the department",
      "user_name": "John Doe",
      "user_id": 1,
      "formatted_time": "1 hour ago",
      "formatted_date": "January 15, 2024",
      "icon": "fas fa-share-alt",
      "color": "text-blue-600",
      "url": "/quizzes/12"
    }
  ],
  "has_more": false,
  "current_page": 1,
  "total_pages": 1,
  "total_count": 1,
  "filters_applied": {
    "activity_types": ["content_sharing", "assignments"],
    "user_id": 1,
    "date_from": "2024-01-01",
    "date_to": null
  }
}
```

---

### 7. Load More Activities

**GET** `/departments/:department_id/activity/load_more`

Loads additional activities for pagination. Returns JSON only.

#### Parameters
- `page` (required): Page number to load
- Inherits filters from current session/state

#### Response Example (200 OK)
```json
{
  "activities": [
    {
      "id": "announcement_321",
      "type": "announcement",
      "title": "Department meeting scheduled",
      "description": "Dr. Smith scheduled a department meeting for next Friday",
      "user_name": "Dr. Smith",
      "user_id": 3,
      "formatted_time": "2 days ago",
      "formatted_date": "January 13, 2024",
      "icon": "fas fa-bullhorn",
      "color": "text-yellow-600",
      "url": "/announcements/18"
    }
  ],
  "has_more": true,
  "current_page": 2,
  "total_pages": 5
}
```

---

## Activity Types

The system tracks the following activity types:

| Type | Description | Icon | Color |
|------|-------------|------|-------|
| `announcements` | Department announcements | `fas fa-bullhorn` | `text-yellow-600` |
| `content_sharing` | Shared assignments, quizzes, notes | `fas fa-share-alt` | `text-blue-600` |
| `member_changes` | Users joining/leaving department | `fas fa-user-plus` | `text-green-600` |
| `assignments` | New assignments created | `fas fa-tasks` | `text-purple-600` |
| `quizzes` | New quizzes created | `fas fa-question-circle` | `text-indigo-600` |
| `notes` | New notes created | `fas fa-sticky-note` | `text-orange-600` |

---

## Error Handling

### Standard Error Response Format
```json
{
  "status": "error",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "Specific field error details"
  }
}
```

### Common Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | `INVALID_PARAMETERS` | Invalid request parameters |
| 401 | `UNAUTHORIZED` | User not authenticated |
| 403 | `FORBIDDEN` | User not authorized for this resource |
| 404 | `NOT_FOUND` | Resource not found |
| 422 | `VALIDATION_ERROR` | Request validation failed |
| 500 | `INTERNAL_ERROR` | Server error |

### Example Error Responses

#### 401 Unauthorized
```json
{
  "status": "error",
  "message": "You must be signed in to access this resource",
  "code": "UNAUTHORIZED"
}
```

#### 403 Forbidden
```json
{
  "status": "error", 
  "message": "You don't have permission to access this department",
  "code": "FORBIDDEN"
}
```

#### 422 Validation Error
```json
{
  "status": "error",
  "message": "Invalid date range provided",
  "code": "VALIDATION_ERROR",
  "details": {
    "start_date": "Start date cannot be in the future",
    "end_date": "End date must be after start date"
  }
}
```

---

## Rate Limiting

- Standard endpoints: 100 requests per minute per user
- Export endpoints: 10 requests per minute per user
- Activity feed: 200 requests per minute per user

Rate limit headers are included in all responses:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642261200
```

---

## Pagination

All paginated endpoints follow consistent pagination patterns:

### Request Parameters
- `page`: Page number (1-based, default: 1)
- `per_page`: Items per page (default: 20, max: 50)

### Response Format
```json
{
  "data": [...],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 89,
    "per_page": 20,
    "has_more": true,
    "has_previous": false
  }
}
```

---

## Caching

- Reports are cached for 15 minutes
- Activity feed is cached for 5 minutes
- Export files are cached for 1 hour
- Cache-Control headers indicate cache status

---

## Security Considerations

1. **Authentication**: All endpoints require valid session authentication
2. **Authorization**: Users can only access their department's data
3. **Input Validation**: All parameters are validated and sanitized
4. **Output Encoding**: All output is properly encoded to prevent XSS
5. **Rate Limiting**: Prevents abuse and ensures fair usage
6. **CSRF Protection**: All state-changing requests require CSRF tokens
7. **SQL Injection Prevention**: All database queries use parameterized statements

---

## Changelog

### Version 1.0 (Week 2 Implementation)
- Initial API implementation
- Basic, detailed, and summary reports
- Activity feed with filtering and pagination
- Export functionality (CSV, PDF, Excel)
- Authentication and authorization
- Rate limiting and caching