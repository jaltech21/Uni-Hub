# Uni-Hub Week 2 Development Documentation

## Architecture Overview

### Week 2 Feature Set
This documentation covers the development implementation of Week 2 features:
- **Task 6**: Department Reports & Exports (PDF, CSV, Excel)
- **Task 7**: Department Activity Feed (Real-time activity tracking)
- **Task 8**: Testing & Documentation (Comprehensive test suite)

### Technology Stack
- **Backend**: Ruby on Rails 8.0.3
- **Frontend**: Tailwind CSS 4.0 with JavaScript/AJAX
- **Database**: PostgreSQL with Active Record
- **PDF Generation**: Prawn 2.5.0
- **Excel Generation**: caxlsx 4.4.0
- **Authentication**: Devise
- **Authorization**: Pundit
- **Testing**: Rails Test Framework

---

## Database Schema

### New Models and Tables

#### 1. ContentSharingHistory
Tracks content sharing activities within departments.

```sql
CREATE TABLE content_sharing_histories (
  id BIGSERIAL PRIMARY KEY,
  shareable_type VARCHAR NOT NULL,
  shareable_id BIGINT NOT NULL,
  department_id BIGINT NOT NULL REFERENCES departments(id),
  shared_by_id BIGINT NOT NULL REFERENCES users(id),
  action VARCHAR NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_content_sharing_department_id ON content_sharing_histories(department_id);
CREATE INDEX idx_content_sharing_created_at ON content_sharing_histories(created_at DESC);
CREATE INDEX idx_content_sharing_shared_by_id ON content_sharing_histories(shared_by_id);
CREATE INDEX idx_content_sharing_polymorphic ON content_sharing_histories(shareable_type, shareable_id);
CREATE INDEX idx_content_sharing_action ON content_sharing_histories(action);
```

**Model Definition:**
```ruby
class ContentSharingHistory < ApplicationRecord
  belongs_to :department
  belongs_to :shared_by, class_name: 'User'
  belongs_to :shareable, polymorphic: true, optional: true

  validates :shareable_type, presence: true, 
    inclusion: { in: %w[Assignment Quiz Note Announcement] }
  validates :shareable_id, presence: true
  validates :action, presence: true,
    inclusion: { in: %w[shared unshared updated removed] }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_department, ->(dept) { where(department: dept) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_type, ->(type) { where(shareable_type: type) }
end
```

#### 2. DepartmentMemberHistory
Tracks membership changes within departments.

```sql
CREATE TABLE department_member_histories (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  department_id BIGINT NOT NULL REFERENCES departments(id),
  action VARCHAR NOT NULL,
  role_before VARCHAR,
  role_after VARCHAR,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_dept_member_history_department_id ON department_member_histories(department_id);
CREATE INDEX idx_dept_member_history_user_id ON department_member_histories(user_id);
CREATE INDEX idx_dept_member_history_created_at ON department_member_histories(created_at DESC);
CREATE INDEX idx_dept_member_history_action ON department_member_histories(action);
CREATE INDEX idx_dept_member_history_user_dept ON department_member_histories(user_id, department_id);
```

**Model Definition:**
```ruby
class DepartmentMemberHistory < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :action, presence: true,
    inclusion: { in: %w[joined left promoted demoted transferred] }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_department, ->(dept) { where(department: dept) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
end
```

### Migration Files

```ruby
# db/migrate/20240115_create_content_sharing_histories.rb
class CreateContentSharingHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :content_sharing_histories do |t|
      t.string :shareable_type, null: false
      t.bigint :shareable_id, null: false
      t.references :department, null: false, foreign_key: true
      t.references :shared_by, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :metadata
      t.timestamps
    end

    add_index :content_sharing_histories, [:shareable_type, :shareable_id]
    add_index :content_sharing_histories, :department_id
    add_index :content_sharing_histories, :created_at
    add_index :content_sharing_histories, :shared_by_id
    add_index :content_sharing_histories, :action
  end
end

# db/migrate/20240115_create_department_member_histories.rb
class CreateDepartmentMemberHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :department_member_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :action, null: false
      t.string :role_before
      t.string :role_after
      t.jsonb :metadata
      t.timestamps
    end

    add_index :department_member_histories, :department_id
    add_index :department_member_histories, :user_id
    add_index :department_member_histories, :created_at
    add_index :department_member_histories, :action
    add_index :department_member_histories, [:user_id, :department_id]
  end
end
```

---

## Service Architecture

### 1. DepartmentReportPdfService

**Purpose**: Generates PDF reports using Prawn gem for department analytics.

**File Location**: `app/services/department_report_pdf_service.rb`

**Key Methods:**
- `generate_basic_report(department, options = {})`: Creates basic overview PDF
- `generate_detailed_report(department, options = {})`: Creates detailed analysis PDF  
- `generate_summary_report(department, options = {})`: Creates executive summary PDF

**Dependencies:**
- Prawn gem for PDF generation
- Department model for data access
- User model for user statistics
- Date/time utilities for filtering

**Architecture Pattern:**
```ruby
class DepartmentReportPdfService
  def initialize
    @pdf = Prawn::Document.new
  end

  private

  def add_header(title, department)
    # PDF header generation
  end

  def add_basic_metrics(data)
    # Basic metrics rendering
  end

  def add_charts_and_graphs(data)
    # Visual data representation
  end

  def finalize_pdf
    @pdf.render
  end
end
```

### 2. ActivityFeedService

**Purpose**: Aggregates and manages activity data from multiple sources.

**File Location**: `app/services/activity_feed_service.rb`

**Key Methods:**
- `load_activities(department, options = {})`: Aggregates activities from all sources
- `activity_types_summary(department)`: Counts activities by type
- `most_active_users(department, limit = 10)`: Returns top active users
- `recent_activity_stats(department)`: Provides recent activity statistics

**Data Sources Integration:**
1. Announcements (from announcements table)
2. Content Sharing (from content_sharing_histories table)
3. Member Changes (from department_member_histories table)
4. Assignments (from assignments table)
5. Quizzes (from quizzes table)
6. Notes (from notes table)

**Architecture Pattern:**
```ruby
class ActivityFeedService
  ACTIVITY_SOURCES = {
    announcements: { model: 'Announcement', icon: 'fas fa-bullhorn' },
    content_sharing: { model: 'ContentSharingHistory', icon: 'fas fa-share-alt' },
    member_changes: { model: 'DepartmentMemberHistory', icon: 'fas fa-user-plus' },
    assignments: { model: 'Assignment', icon: 'fas fa-tasks' },
    quizzes: { model: 'Quiz', icon: 'fas fa-question-circle' },
    notes: { model: 'Note', icon: 'fas fa-sticky-note' }
  }.freeze

  private

  def collect_from_source(source_key, source_config, department, options)
    # Dynamic data collection from different models
  end

  def format_activity(record, source_key, source_config)
    # Standardizes activity format across sources
  end
end
```

---

## Controller Architecture

### 1. Departments::ReportsController

**Purpose**: Handles department report generation and export functionality.

**File Location**: `app/controllers/departments/reports_controller.rb`

**Actions:**
- `index`: Main reports dashboard
- `basic`: Generates basic report data
- `detailed`: Generates detailed report data  
- `summary`: Generates summary report data
- `export`: Handles file exports (CSV, PDF, Excel)

**Authorization**: Uses Pundit for department access control
**Authentication**: Requires user session via Devise

**Key Features:**
- Date range filtering
- Multiple export formats
- Caching for performance
- Error handling and validation

### 2. Departments::ActivityController

**Purpose**: Manages department activity feed functionality.

**File Location**: `app/controllers/departments/activity_controller.rb`

**Actions:**
- `index`: Main activity feed page
- `filter`: AJAX endpoint for filtered activities
- `load_more`: AJAX endpoint for pagination

**AJAX Support**: Full AJAX implementation for real-time filtering and pagination
**Response Formats**: HTML for initial load, JSON for AJAX requests

---

## Frontend Architecture

### JavaScript Organization

**File Location**: `app/javascript/application.js` (and view-specific inline scripts)

**Key Components:**
1. **Activity Feed Manager**: Handles filtering, pagination, AJAX requests
2. **Report Generator**: Manages report generation UI and progress
3. **Export Handler**: Manages file downloads and progress indicators
4. **Date Picker Integration**: Custom date range controls

**AJAX Implementation Pattern:**
```javascript
// Activity filtering
function filterActivities() {
  const formData = new FormData(document.getElementById('filter-form'));
  
  fetch('/departments/' + departmentId + '/activity/filter', {
    method: 'POST',
    headers: {
      'X-Requested-With': 'XMLHttpRequest',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: formData
  })
  .then(response => response.json())
  .then(data => updateActivityFeed(data))
  .catch(error => handleError(error));
}
```

### CSS Architecture (Tailwind CSS)

**Styling Approach**: Utility-first with Tailwind CSS 4.0
**Responsive Design**: Mobile-first responsive design
**Component Structure**: Modular component-based styling

**Key Design Patterns:**
- Card-based layouts for reports and activities
- Consistent color scheme and spacing
- Accessible form controls and navigation
- Loading states and progress indicators

---

## Testing Architecture

### Test Organization

```
test/
├── controllers/
│   └── departments/
│       ├── reports_controller_test.rb
│       └── activity_controller_test.rb
├── services/
│   ├── department_report_pdf_service_test.rb
│   └── activity_feed_service_test.rb
├── models/
│   ├── content_sharing_history_test.rb
│   └── department_member_history_test.rb
├── integration/
│   ├── department_reports_integration_test.rb
│   └── activity_feed_integration_test.rb
└── views/
    ├── department_reports_view_test.rb
    └── activity_feed_view_test.rb
```

### Test Coverage Areas

1. **Controller Tests**: Authentication, authorization, response validation
2. **Service Tests**: Business logic, data processing, error handling
3. **Model Tests**: Validations, associations, scoping, business rules
4. **Integration Tests**: End-to-end workflows, user journeys
5. **View Tests**: UI rendering, accessibility, security

### Testing Utilities

**Fixtures**: Comprehensive test data setup
**Factory Pattern**: Dynamic test data generation
**Mock Objects**: External service simulation
**Test Helpers**: Shared testing utilities

---

## Routing Configuration

### Route Structure

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :departments do
    scope module: :departments do
      resources :reports, only: [:index] do
        collection do
          get :basic
          get :detailed
          get :summary
          get :export
        end
      end
      
      resources :activity, only: [:index] do
        collection do
          get :filter
          get :load_more
        end
      end
    end
  end
end
```

**Generated Routes:**
- `GET /departments/:id/reports` - Reports dashboard
- `GET /departments/:id/reports/basic` - Basic report generation
- `GET /departments/:id/reports/detailed` - Detailed report generation
- `GET /departments/:id/reports/summary` - Summary report generation
- `GET /departments/:id/reports/export` - Export functionality
- `GET /departments/:id/activity` - Activity feed
- `GET /departments/:id/activity/filter` - Activity filtering
- `GET /departments/:id/activity/load_more` - Activity pagination

---

## Security Implementation

### Authentication & Authorization

**Authentication**: Devise gem integration
- Session-based authentication
- User sign-in required for all endpoints
- Session timeout and security features

**Authorization**: Pundit gem integration
- Department-based access control
- Role-based permissions (admin, teacher, student)
- Policy-driven authorization rules

```ruby
# app/policies/department_policy.rb
class DepartmentPolicy < ApplicationPolicy
  def reports?
    user.present? && (user.department == record || user.admin?)
  end

  def activity?
    user.present? && (user.department == record || user.admin?)
  end
end
```

### Input Validation & Sanitization

**Parameter Filtering**: Strong parameters in controllers
**SQL Injection Prevention**: Parameterized queries via Active Record
**XSS Prevention**: Rails automatic HTML escaping
**CSRF Protection**: Rails built-in CSRF tokens

### Rate Limiting & Performance

**Caching Strategy**:
- Report data cached for 15 minutes
- Activity feed cached for 5 minutes  
- Export files cached for 1 hour

**Rate Limiting**:
- 100 requests/minute for standard endpoints
- 10 requests/minute for export endpoints
- 200 requests/minute for activity feed

---

## Performance Optimization

### Database Optimization

**Indexing Strategy**:
- Indexes on frequently queried columns
- Composite indexes for multi-column queries
- Partial indexes for filtered queries

**Query Optimization**:
- Eager loading to prevent N+1 queries
- Database-level aggregations
- Pagination to limit result sets

### Caching Strategy

**Application-Level Caching**:
- Russian Doll caching for complex views
- Fragment caching for expensive computations
- Query result caching for reports

**HTTP Caching**:
- ETag headers for cache validation
- Cache-Control headers for browser caching
- CDN integration for static assets

### Background Processing

**Async Processing**: (Planned for future iterations)
- Background jobs for large report generation
- Email delivery for completed exports
- Scheduled maintenance tasks

---

## Deployment Configuration

### Environment Configuration

**Development Environment**:
- Local PostgreSQL database
- Rails development server
- Asset pipeline with debugging
- Verbose logging enabled

**Production Environment**:
- Production database configuration
- Asset precompilation
- Optimized caching settings
- Error tracking integration

### Dependencies

**Gemfile Additions for Week 2**:
```ruby
# PDF generation
gem 'prawn', '~> 2.5.0'

# Excel generation  
gem 'caxlsx', '~> 4.4.0'

# Additional gems for enhanced functionality
gem 'pundit', '~> 2.3.0'  # Authorization
gem 'image_processing', '~> 1.2'  # Image handling
```

### Server Requirements

**Minimum Requirements**:
- Ruby 3.4.3+
- Rails 8.0.3+
- PostgreSQL 13+
- 2GB RAM minimum
- 10GB disk space

**Recommended Requirements**:
- 4GB+ RAM for better performance
- SSD storage for database
- Redis for caching and background jobs
- Load balancer for high availability

---

## API Documentation Reference

### RESTful API Design

**Endpoint Patterns**:
- Resource-based URLs
- HTTP verbs for actions
- Consistent response formats
- Proper status codes

**Response Format**:
```json
{
  "status": "success|error",
  "data": { ... },
  "message": "Human readable message",
  "pagination": { ... },
  "metadata": { ... }
}
```

### Content Negotiation

**Supported Formats**:
- JSON for API responses
- HTML for web interface
- CSV/PDF/Excel for exports

**Headers**:
- `Accept: application/json` for API requests
- `Content-Type: application/json` for API responses
- `X-Requested-With: XMLHttpRequest` for AJAX

---

## Development Setup

### Local Development Environment

**Prerequisites**:
1. Ruby 3.4.3 (via rbenv or RVM)
2. Rails 8.0.3
3. PostgreSQL 13+
4. Node.js 18+ (for asset compilation)
5. Yarn package manager

**Setup Steps**:
```bash
# Clone repository
git clone [repository-url]
cd uni-hub

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
yarn install

# Setup database
rails db:create
rails db:migrate
rails db:seed

# Run development server
rails server
```

### Running Tests

**Full Test Suite**:
```bash
# Run all tests
rails test

# Run specific test categories
rails test test/controllers/
rails test test/services/
rails test test/models/
rails test test/integration/
rails test test/views/

# Run with coverage
COVERAGE=true rails test
```

**Individual Test Files**:
```bash
# Test specific controller
rails test test/controllers/departments/reports_controller_test.rb

# Test specific service
rails test test/services/activity_feed_service_test.rb
```

### Development Tools

**Recommended Tools**:
- VS Code with Ruby and Rails extensions
- Database management tool (pgAdmin, TablePlus)
- API testing tool (Postman, Insomnia)
- Browser developer tools
- Git for version control

**Debugging Tools**:
- `byebug` for debugging Ruby code
- Rails console for interactive testing
- Browser inspector for frontend debugging
- Rails logs for request tracking

---

## Troubleshooting Guide

### Common Development Issues

**Database Connection Issues**:
```bash
# Check PostgreSQL status
pg_ctl status

# Restart PostgreSQL
brew services restart postgresql  # macOS
sudo service postgresql restart   # Linux
```

**Asset Compilation Issues**:
```bash
# Clear asset cache
rails assets:clobber

# Precompile assets
rails assets:precompile
```

**Test Failures**:
```bash
# Reset test database
RAILS_ENV=test rails db:drop db:create db:migrate

# Load test fixtures
RAILS_ENV=test rails db:fixtures:load
```

### Performance Issues

**Slow Queries**:
- Check database indexes
- Analyze query execution plans
- Consider database query optimization

**Memory Issues**:
- Monitor Rails memory usage
- Check for memory leaks in long-running processes
- Optimize object allocation

### Production Deployment Issues

**Database Migration**:
```bash
# Run migrations safely
rails db:migrate:status
rails db:migrate
```

**Asset Compilation**:
```bash
# Precompile assets for production
RAILS_ENV=production rails assets:precompile
```

---

## Future Development Considerations

### Scalability Improvements

**Database Scaling**:
- Read replicas for heavy read workloads
- Database partitioning for large tables
- Connection pooling optimization

**Application Scaling**:
- Horizontal scaling with load balancers
- Background job processing with Redis/Sidekiq
- Microservices architecture for large deployments

### Feature Enhancements

**Planned Improvements**:
- Real-time notifications via WebSockets
- Advanced analytics and dashboards
- Mobile application API
- Integration with external systems

### Code Quality

**Code Standards**:
- RuboCop for Ruby style enforcement
- ESLint for JavaScript code quality
- Code coverage targets (90%+)
- Regular security audits

**Documentation Standards**:
- Inline code documentation
- API documentation maintenance
- Architecture decision records
- Regular documentation updates

---

This development documentation provides comprehensive technical details for maintaining, extending, and deploying the Week 2 features. It serves as a reference for developers working on the Uni-Hub project and includes all necessary technical specifications for successful implementation and maintenance.