# Implementation Log - UniHub Phase 1

## Todo #1: Enhance Assignment Model & Database ✅ COMPLETED

### Date: October 29, 2025

### Changes Made:

#### 1. Database Migration
Created migration: `20251029142225_enhance_assignments_and_submissions.rb`

**Assignments Table - New Fields:**
- `points` (integer, default: 100) - Maximum points for the assignment
- `category` (string, default: 'homework') - Type: homework/project/quiz/exam
- `grading_criteria` (text) - Detailed grading rubric and criteria
- `allow_resubmission` (boolean, default: false) - Allow students to resubmit
- `course_name` (string) - Course/subject name for organization

**Submissions Table - New Fields:**
- `grade` (integer) - Points earned by student
- `feedback` (text) - Teacher's feedback on submission
- `submitted_at` (datetime) - Timestamp when student submitted
- `graded_at` (datetime) - Timestamp when teacher graded
- `graded_by_id` (bigint) - Foreign key to users table (teacher who graded)
- Added index and foreign key constraint for `graded_by_id`

#### 2. Assignment Model Updates (`app/models/assignment.rb`)

**Changes:**
- Changed `has_one_attached :file` to `has_many_attached :files` for multiple file support
- Added comprehensive validations:
  - Title: presence, length 3-255 characters
  - Description: presence
  - Due date: presence
  - Points: must be >= 0
  - Category: must be homework/project/quiz/exam
  
**New Scopes:**
- `by_category(category)` - Filter by assignment type
- `by_course(course)` - Filter by course name
- `upcoming` - Assignments with future due dates
- `overdue` - Assignments past due date
- `recent` - Order by creation date

**New Instance Methods:**
- `overdue?` - Check if past due date
- `submitted_count` - Count submissions with submitted_at
- `graded_count` - Count submissions with graded_at
- `pending_submissions_count` - Count submissions without submitted_at
- `average_grade` - Calculate average grade across all submissions

**Ransack Updates:**
- Added searchable attributes: category, course_name, points
- Added searchable association: submissions

#### 3. Submission Model Updates (`app/models/submission.rb`)

**Changes:**
- Changed `has_one_attached :document` to `has_many_attached :documents` for multiple files
- Added `belongs_to :graded_by` association (optional, references User)
- Updated validations:
  - Documents: presence on create
  - Grade: must be >= 0 and <= assignment.points
  - Status: must be pending/submitted/graded
- Changed document validation to only check on create

**New Callbacks:**
- `before_create :set_submitted_at` - Auto-set submission timestamp and status
- `after_update :set_graded_at` - Auto-set graded timestamp when grade changes

**New Scopes:**
- `pending` - Submissions with pending status
- `submitted` - Submissions with submitted status
- `graded` - Submissions with graded status
- `by_student(user_id)` - Filter by student
- `recent` - Order by submission date

**New Instance Methods:**
- `late_submission?` - Check if submitted after due date
- `percentage_grade` - Calculate grade as percentage
- `letter_grade` - Convert percentage to letter grade (A/B/C/D/F)
- `grade_with_feedback?` - Check if both grade and feedback exist

**Ransack Updates:**
- Added searchable attributes: grade, submitted_at, graded_at
- Added searchable association: graded_by

#### 4. Active Storage Configuration
- Assignments now support multiple file attachments (`:files`)
- Submissions now support multiple document uploads (`:documents`)
- Active Storage tables already exist in database from initial setup

### Testing Results:
✅ Migration ran successfully (0.2701s)
✅ Assignment model validations working correctly
✅ Submission model validations working correctly
✅ All fields visible in schema.rb
✅ Foreign key constraints properly added

### Technical Notes:
- Used `has_many_attached` instead of `has_one_attached` for flexibility
- Added proper indexes for performance on graded_by_id
- Validations include custom proc for dynamic max grade checking
- Status field uses enum-like validation with inclusion
- Callbacks handle automatic timestamp management
- Scopes use conditional logic to avoid nil errors

### Next Steps:
Ready to proceed to **Todo #2: Teacher - Enhanced Assignment Creation Form**

This will involve:
- Creating comprehensive form with file upload support
- Implementing Vanilla JS for file upload preview
- Adding rich text editor for description
- Category dropdown selection
- Points input with validation
- Due date picker
- Course name input

---

## Todo #2: Teacher - Enhanced Assignment Creation Form ✅ COMPLETED

### Date: October 29, 2025

### Changes Made:

#### 1. Controller Updates (`app/controllers/assignments_controller.rb`)

**Updated `create` action:**
- Changed from `Assignment.new(assignment_params)` to `current_user.assignments.build(assignment_params)`
- This automatically sets the `user_id` (teacher) for the assignment
- Added `status: :unprocessable_entity` for better error handling

**Updated `assignment_params` method:**
Added new permitted parameters:
- `:points` - Maximum points for assignment
- `:category` - Assignment type (homework/project/quiz/exam)
- `:grading_criteria` - Detailed rubric
- `:allow_resubmission` - Boolean for resubmission permission
- `:course_name` - Course/subject name
- `files: []` - Array of attached files (Active Storage)

#### 2. Form Partial Creation (`app/views/assignments/_form.html.erb`)

**Form Features:**
- **Responsive Design**: Tailwind CSS utility classes, mobile-friendly
- **Error Display**: Red alert box showing validation errors with count
- **11 Form Fields**:
  1. Title - Text input with placeholder
  2. Course Name - Text input for organization
  3. Category - Dropdown (homework/project/quiz/exam)
  4. Points - Number input with min validation
  5. Due Date - datetime_local_field with default 1 week ahead
  6. Description - Large textarea (6 rows)
  7. Grading Criteria - Optional textarea (4 rows)
  8. File Upload - Drag & drop zone with multiple file support
  9. File Preview - Dynamic list showing uploaded files
  10. Allow Resubmission - Checkbox option
  11. Submit/Cancel buttons

**Visual Design:**
- Clean white card with shadow
- Blue accent color for focus states
- Proper spacing and typography
- Helpful hints under fields
- Icons for file upload zone
- File type icons (📄 PDF, 📝 DOC, 🗜️ ZIP, 🖼️ Images, 📃 Text)

#### 3. Vanilla JavaScript Implementation

**File Upload Features:**
```javascript
// Global state management
let selectedFiles = [];
const MAX_FILE_SIZE = 10MB;
const ALLOWED_TYPES = ['pdf', 'doc', 'docx', 'txt', 'zip', 'jpg', 'jpeg', 'png'];
```

**Drag & Drop Support:**
- Prevents default browser behavior for drag events
- Visual feedback when hovering (blue border, blue background)
- Event listeners for: dragenter, dragover, dragleave, drop
- Handles dropped files same as selected files

**File Validation:**
1. **Size Check**: Max 10MB per file with user alert
2. **Type Check**: Only allowed extensions with user alert
3. **Duplicate Check**: Prevents adding same file twice
4. **Real-time Preview**: Shows file icon, name, size after validation

**File Preview Display:**
- Gray background card for each file
- File icon based on type
- File name and formatted size (Bytes/KB/MB)
- Remove button (X icon) to delete file
- Updates file input on add/remove

**Form Validation Before Submit:**
- Title: Must be at least 3 characters
- Description: Required field check
- Due Date: Must be selected
- Points: Must be 0 or greater
- Shows alert messages for each validation failure
- Prevents form submission until valid
- Disables submit button after click to prevent double submission
- Changes button text to "Creating..." with opacity

**Helper Functions:**
- `preventDefaults()` - Stops default drag behaviors
- `validateFile()` - Checks size, type, duplicates
- `displayFilePreview()` - Creates file preview element
- `getFileIcon()` - Returns emoji based on file type
- `formatFileSize()` - Converts bytes to readable format
- `removeFile()` - Removes file from array and preview
- `updateFileInput()` - Syncs file input with selected files array

#### 4. View File Updates

**new.html.erb:**
```erb
<%= render 'form', assignment: @assignment %>
```
- Simplified to single line rendering partial
- Passes `@assignment` instance variable

**edit.html.erb (NEW FILE):**
```erb
<%= render 'form', assignment: @assignment %>
```
- Created new file for edit action
- Reuses same form partial
- Form automatically detects persisted record for edit mode

#### 5. Form Behavior

**Create Mode:**
- Shows "Create New Assignment" header
- Submit button says "Create Assignment"
- Cancel button goes back to assignments index
- Default values: 100 points, 'homework' category, 1 week due date

**Edit Mode:**
- Shows "Edit Assignment" header  
- Submit button says "Update Assignment"
- Cancel button goes to assignment show page
- Displays current values in all fields
- Existing files shown (if any)

### Testing Notes:
✅ No syntax errors in controller or views
✅ Routes already configured (`resources :assignments`)
✅ Form accessible at `/assignments/new` (teachers only)
✅ All Tailwind CSS classes available
✅ JavaScript runs client-side without dependencies
✅ File upload supports Active Storage direct uploads

### Technical Highlights:
- **Zero Framework Dependencies**: Pure Vanilla JS, no jQuery/React/Vue
- **Progressive Enhancement**: Form works even if JS fails to load
- **Security**: Server-side validation in model, client-side for UX
- **Performance**: Uses DataTransfer API for efficient file handling
- **Accessibility**: Proper labels, ARIA attributes, keyboard navigation
- **Responsive**: Mobile-first design with Tailwind utilities

### Next Steps:
Ready to proceed to **Todo #3: Teacher - Assignment Dashboard**

This will involve:
- Creating assignments index page with cards/table view
- Displaying submission statistics for each assignment
- Adding filters for category, course, status (upcoming/overdue)
- Implementing Vanilla JS for client-side filtering
- Sort options without page reload
- Quick actions (view, edit, delete)

---

## Todo #3: Teacher - Assignment Dashboard ✅ COMPLETED

### Date: October 29, 2025

### Changes Made:

#### 1. Controller Updates (`app/controllers/assignments_controller.rb`)

**Updated `index` action:**
- Added role-based conditional logic
- Teachers see only their own assignments: `current_user.assignments`
- Added `.includes(:submissions)` for eager loading (N+1 query prevention)
- Ordered by `created_at: :desc` (newest first)
- Students see all assignments (placeholder, will be enhanced in Todo #7)
- Removed `authorize_student!` filter to allow both roles

**Removed `authorize_student!` method:**
- Index is now accessible to both teachers and students
- Authorization still applies to create/edit/delete actions

#### 2. Teacher Dashboard View (`app/views/assignments/index.html.erb`)

**Header Section:**
- Professional page title: "My Assignments"
- Subtitle: "Manage and track all your assignments"
- "Create New Assignment" button with icon (blue, prominent)

**Statistics Cards (4 cards):**
1. **Total Assignments**
   - Shows count of all assignments
   - Blue left border, document icon
   - Updates dynamically with filters

2. **Upcoming Assignments**
   - Shows count where `due_date > Time.current`
   - Green left border, calendar icon
   - Filters assignments that haven't passed due date

3. **Overdue Assignments**
   - Shows count where `due_date < Time.current`
   - Yellow left border, clock icon
   - Highlights late assignments

4. **Total Submissions**
   - Shows sum of all submissions across assignments
   - Purple left border, checkmark icon
   - Uses `submitted_count` method from model

**Filters Section (4 filters):**
1. **Search Input**
   - Real-time text search by assignment title
   - Placeholder: "Search assignments..."
   - Case-insensitive matching

2. **Category Filter**
   - Dropdown with 5 options: All, Homework, Project, Quiz, Exam
   - Filters by `assignment.category`
   - Shows category badge colors

3. **Status Filter**
   - Dropdown with 3 options: All, Upcoming, Overdue
   - Based on due date comparison with current time
   - Visual indicators in table

4. **Sort Dropdown**
   - 6 sort options:
     - Newest First (default)
     - Oldest First
     - Due Date (Soon)
     - Due Date (Later)
     - Title (A-Z)
     - Title (Z-A)
   - Instant re-ordering without page reload

**Assignments Table:**
- Clean, professional table layout with hover effects
- 6 columns with detailed information

**Column 1: Assignment**
- Assignment title (clickable link to show page)
- Course name below (if provided)
- Font styling for hierarchy

**Column 2: Category**
- Color-coded badges:
  - Homework: Blue (`bg-blue-100 text-blue-800`)
  - Project: Purple (`bg-purple-100 text-purple-800`)
  - Quiz: Yellow (`bg-yellow-100 text-yellow-800`)
  - Exam: Red (`bg-red-100 text-red-800`)
- Capitalized category name

**Column 3: Due Date**
- Date: "Jan 15, 2025" format
- Time: "11:59 PM" format (12-hour)
- Overdue indicator: Red badge with X icon if past due

**Column 4: Points**
- Displays maximum points (e.g., "100 pts")
- Simple, clear formatting

**Column 5: Submissions**
- **Submitted count**: Green checkmark icon + number
- **Graded count**: Blue clipboard icon + number
- Two-line display for clear statistics
- Uses model methods: `submitted_count`, `graded_count`

**Column 6: Actions**
- 3 icon buttons in a row:
  1. **View** (eye icon): Blue, links to show page
  2. **Edit** (pencil icon): Indigo, links to edit page
  3. **Delete** (trash icon): Red, enhanced confirmation dialog
- Hover effects for all buttons

**Empty State:**
- Shows when no assignments exist
- Large document icon in gray
- Friendly message: "No assignments yet"
- Call-to-action button to create first assignment

**No Results State:**
- Hidden by default
- Shows when filters return no matches
- Search icon, helpful message
- Suggestion to adjust filters

#### 3. Vanilla JavaScript Implementation

**Global Variables:**
```javascript
const searchInput, categoryFilter, statusFilter, sortSelect
const tableBody, noResults
const statTotal, statUpcoming, statOverdue
let allRows = Array.from(document.querySelectorAll('.assignment-row'))
```

**Data Attributes on Each Row:**
- `data-title`: Lowercase title for search matching
- `data-category`: Assignment category (homework/project/quiz/exam)
- `data-status`: "upcoming" or "overdue" based on due date
- `data-due-date`: Unix timestamp for date sorting
- `data-created-at`: Unix timestamp for creation date sorting

**Main Function: `filterAndSort()`**
1. Reads current values from all filters
2. Filters rows based on all criteria (AND logic)
3. Hides non-matching rows, shows matching ones
4. Sorts visible rows based on selected sort option
5. Re-orders rows in DOM (no page reload)
6. Updates statistics cards with new counts
7. Shows/hides "no results" message

**Filter Logic:**
- **Search**: Includes substring match on title (case-insensitive)
- **Category**: Exact match on category attribute
- **Status**: Exact match on status attribute
- All filters combine with AND logic

**Sort Algorithms:**
- **Newest/Oldest**: Sorts by `created_at` timestamp
- **Due Soon/Late**: Sorts by `due_date` timestamp
- **Title A-Z/Z-A**: Alphabetical sort using `localeCompare()`
- Uses Array.sort() with custom comparator functions

**Statistics Update Function:**
```javascript
function updateStats(visibleRows)
```
- Counts total visible rows
- Filters by status for upcoming/overdue counts
- Updates DOM text content of stat cards
- Provides live feedback as filters change

**Event Listeners:**
- `input` event on search field (real-time typing)
- `change` event on all dropdowns
- All trigger `filterAndSort()` function
- No debouncing needed (performance is good)

**Enhanced Delete Confirmation:**
- Custom confirmation dialog with detailed warning
- Lists what will be deleted:
  - The assignment
  - All student submissions
  - All grades and feedback
- Prevents accidental deletions
- Uses native `confirm()` for compatibility
- Programmatically submits DELETE form if confirmed
- Includes CSRF token for security

#### 4. Student View Partial (`_student_view.html.erb`)

**Purpose:**
- Placeholder for Todo #7 (Student Assignment Dashboard)
- Shows basic assignment cards
- Simpler interface than teacher dashboard

**Features:**
- Grid layout (3 columns on large screens)
- Assignment cards with:
  - Title and course name
  - Category badge
  - Points display
  - Due date with icon
  - "View Details" button
- Empty state with friendly message
- Note at bottom: "Full student dashboard will be implemented in Todo #7"

#### 5. Responsive Design

**Breakpoints:**
- Mobile: Single column layout, stacked stats
- Tablet (md): 2 columns for stats/filters
- Desktop (lg): 4 columns for stats, full table
- Extra Large (xl): Optimized spacing

**Mobile Optimizations:**
- Table becomes scrollable horizontally
- Buttons remain tappable (44x44px minimum)
- Cards stack vertically
- No loss of functionality

### Testing Notes:
✅ No syntax errors in views or controller  
✅ Role-based rendering works (teacher vs student)  
✅ Statistics calculate correctly from model methods  
✅ All filters and sort work independently  
✅ Combines filters properly (AND logic)  
✅ Real-time updates without page reload  
✅ Enhanced delete confirmation prevents accidents  
✅ Empty states display correctly  

### Technical Highlights:
- **Zero Dependencies**: Pure Vanilla JS, no libraries
- **Performance**: Uses data attributes for instant filtering
- **Eager Loading**: `.includes(:submissions)` prevents N+1 queries
- **Live Statistics**: Updates counts as filters change
- **Accessibility**: Proper labels, semantic HTML, keyboard navigation
- **Responsive**: Mobile-first Tailwind design
- **Security**: CSRF tokens in delete forms

### Features Summary:
✅ 4 real-time statistics cards  
✅ Search by title  
✅ Filter by category (4 types)  
✅ Filter by status (upcoming/overdue)  
✅ Sort by 6 different criteria  
✅ Professional table with 6 columns  
✅ Color-coded category badges  
✅ Submission statistics per assignment  
✅ Overdue indicators  
✅ Quick action buttons (view/edit/delete)  
✅ Enhanced delete confirmation  
✅ Empty state when no assignments  
✅ No results state when filters match nothing  
✅ Separate student view (basic placeholder)  
✅ Mobile responsive  

### Next Steps:
Ready to proceed to **Todo #4: Teacher - View Student Submissions**

This will involve:
- Creating submissions index page for a specific assignment
- Displaying all student submissions in a table
- Show student names, submission timestamps, file counts
- Download individual files
- Download all files as ZIP (bulk download)
- Grade input field for each submission
- Feedback textarea for each submission
- Vanilla JS for inline editing and file downloads

---

## Todo #4: Teacher View Student Submissions ✅ COMPLETED

### Date: January 29, 2025

### Changes Made:

#### 1. Controller Updates (`app/controllers/submissions_controller.rb`)

**Added Authorization:**
- Added `authorize_teacher!` before_action for index
- Added ownership check: only assignment creator can view submissions
- Redirects unauthorized users to root with alert message

**Enhanced Index Action:**
- Added eager loading: `.includes(:user, documents_attachments: :blob)`
- Orders submissions by `submitted_at: :desc` (newest first)
- Prevents N+1 queries for users and file attachments

**Updated Parameters:**
- Changed from `:file` (singular) to `documents: []` (array)
- Maintains `:status` parameter
- Supports multiple file uploads per submission

#### 2. Comprehensive Submissions View (`app/views/submissions/index.html.erb`)

**Header Section:**
- Assignment title, course name, category, points display
- Due date with formatted timestamp
- Overdue badge if past due date
- "Back to Assignments" button with left arrow icon

**Statistics Cards (4 cards in grid):**
1. **Total Submissions**: Blue left border, document icon, shows count
2. **Submitted**: Green left border, checkmark icon, counts submitted status
3. **Graded**: Purple left border, clipboard icon, counts graded status
4. **Average Grade**: Yellow left border, star icon, displays percentage or N/A

**Filters Section (3 inputs in grid):**
1. **Search**: Text input to search by student name (real-time)
2. **Status Filter**: Dropdown - All Status/Submitted/Graded/Late Submission
3. **Sort**: Dropdown with 6 options
   - Newest First (default)
   - Oldest First
   - Name A-Z
   - Name Z-A
   - Highest Grade
   - Lowest Grade

**Submissions Table (6 columns):**
1. **Student**: 
   - Circular avatar with initials
   - Full name (bold)
   - Email address (gray)
2. **Status**: 
   - Purple badge with checkmark for "Graded"
   - Green badge with checkmark for "Submitted"
   - Red badge for "Late" (if submitted after due date)
3. **Submitted At**: 
   - Date formatted (MMM DD, YYYY)
   - Time formatted (HH:MM AM/PM)
4. **Files**: 
   - File count with plural handling
   - "View files" toggle button (blue)
5. **Grade**: 
   - Points earned/total points
   - Percentage with letter grade (A/B/C/D/F)
   - "Not graded" if no grade
6. **Actions**: 
   - View icon (eye) - links to show page
   - Edit icon (pencil) - links to edit page for grading

**File List Rows (expandable):**
- Hidden by default, revealed by "View files" button
- Gray background to distinguish from submission rows
- Shows all attached documents in a list
- Each file displays:
  - Document icon
  - Filename
  - File size (human-readable format)
  - Download button with icon
- Clean white cards with borders for each file

**Empty States:**
- **No submissions**: Document icon, "No submissions yet", friendly message
- **No results from filtering**: Search icon, "No submissions found", adjustment suggestion

#### 3. Vanilla JavaScript Features (150+ lines)

**Filtering Logic:**
- Search by student name (case-insensitive, includes partial matches)
- Filter by status: submitted, graded, or late submissions
- AND logic for combining search + status filters
- Real-time filtering on input/change events
- Uses data attributes for efficient querying

**Sorting Options:**
- Newest/oldest by submission timestamp (Unix timestamp comparison)
- Alphabetical by student name (A-Z or Z-A, locale-aware)
- By grade (highest to lowest or vice versa, numeric comparison)
- DOM reordering without page reload
- Maintains row associations (submission + file list)

**Statistics Updates:**
- Dynamically recalculates based on visible rows
- Updates total, submitted, and graded counts in stat cards
- Reflects current filter state (not full dataset)
- Real-time updates as filters change

**File Viewing:**
- Toggle file list visibility per submission
- Button text changes: "View files" ↔ "Hide files"
- Maintains state for each submission independently
- Preserves file rows during filtering/sorting operations
- Uses data-submission-id for row association

**Performance Optimizations:**
- Uses data attributes (data-student-name, data-status, data-late, data-grade, data-submitted-at)
- Array.from() for clean array operations
- Event delegation for dynamic content
- No DOM queries inside loops
- No jQuery or frameworks needed (pure Vanilla JS)

### Technical Highlights:

1. **Authorization**: Teacher-only access with ownership validation
2. **Eager Loading**: Prevents N+1 queries with `.includes(:user, documents_attachments: :blob)`
3. **Responsive Design**: Grid layout adapts to screen sizes (1/2/4 columns)
4. **Status Badges**: Color-coded visual indicators (green/purple/red)
5. **Avatar Initials**: Generated from user's full name split and uppercase
6. **File Management**: Multiple files per submission with individual downloads
7. **Late Detection**: Uses `late_submission?` method from Submission model
8. **Letter Grades**: Displays calculated letter grade using `letter_grade` method
9. **Empty States**: Helpful messages for both scenarios (no data vs no results)
10. **Filter Persistence**: Maintains row associations during reordering
11. **Download Links**: Uses `rails_blob_path` with attachment disposition
12. **Human-Readable Sizes**: Uses `number_to_human_size` helper for file sizes

### Testing Notes:

**Access the submissions page:**
```ruby
# In Rails console
assignment = Assignment.first
# Navigate to: /assignments/:id/submissions
```

**Create test submissions:**
```ruby
student = User.find_by(role: 'student')
submission = assignment.submissions.create(
  user: student,
  status: 'submitted'
)
submission.documents.attach(
  io: File.open('path/to/file.pdf'),
  filename: 'homework.pdf'
)
```

**Verify features:**
1. ✅ Teacher can access submissions for their assignments
2. ✅ Other teachers cannot access (redirected with alert)
3. ✅ Students cannot access (redirected with alert)
4. ✅ Statistics calculate correctly (total, submitted, graded, average)
5. ✅ Search filters by student name (case-insensitive)
6. ✅ Status filter shows correct submissions (submitted/graded/late)
7. ✅ Sorting reorders rows without page reload
8. ✅ File toggle shows/hides file lists for each submission
9. ✅ Download links work for each file
10. ✅ Late submissions show red "Late" badge
11. ✅ Graded submissions display grade with percentage and letter
12. ✅ Empty state appears when no submissions exist
13. ✅ No results message appears when filters return empty
14. ✅ Statistics update based on filtered results

**Database Verification:**
```ruby
# Check submission associations
submission = Submission.first
submission.user.full_name  # Should show student name
submission.documents.attached?  # Should be true
submission.documents.count  # Number of files
submission.late_submission?  # Check late status
submission.letter_grade  # Should return A/B/C/D/F or nil
submission.percentage_grade  # Numeric percentage

# Check eager loading works
Assignment.includes(:submissions).first.submissions.count
# Should not trigger additional queries

# Check authorization
assignment.user_id  # Should match current teacher's ID
```

### Next Steps:
Ready to proceed to **Todo #5: Teacher - Grade & Provide Feedback**

This will involve:
- Creating/updating submission edit/show pages
- Inline grading interface on submissions index
- Grade input field with validation (0 to assignment.points)
- Feedback textarea with character counter
- Auto-save functionality with AJAX
- Visual feedback on save (success/error messages)
- Update statistics after grading
- Display grading history (graded_at, graded_by)
- Vanilla JS for seamless inline editing experience

---

## Todo #5: Teacher Grade & Provide Feedback ✅ COMPLETED

### Date: January 29, 2025

### Changes Made:

#### 1. Controller Updates (`app/controllers/submissions_controller.rb`)

**Added Actions:**
- **show**: View submission details (accessible by student owner or teachers)
  - Authorization: Students can only view their own submissions
  - Teachers can view all submissions for their assignments
  - Redirects unauthorized users with alert

- **edit**: Display grading form for teachers
  - Authorization: Only assignment creator can grade
  - Loads submission with assignment context
  - Checks ownership before allowing access

- **update**: Save grades and feedback
  - Authorization: Only assignment creator can grade
  - Sets `graded_by` to current_user when grade is provided
  - Supports both HTML and JSON responses
  - JSON response includes submission data for auto-save
  - Returns success/error messages

**New Helper Methods:**
- `set_submission`: Finds submission by ID within assignment scope
- `grading_params`: Permits only `:grade` and `:feedback` parameters
- `submission_json`: Returns formatted JSON with:
  - Grade, feedback, percentage, letter grade
  - Formatted graded_at timestamp
  - Graded by teacher's full name
  - Current status

**Updated Before Actions:**
- Extended `set_assignment` to include show, edit, update
- Extended `authorize_teacher!` to include edit, update
- Added `set_submission` for show, edit, update

#### 2. Grading Form View (`app/views/submissions/edit.html.erb`)

**Layout Structure:**
- Two-column layout: Main form (2/3 width) + Sidebar (1/3 width)
- Responsive grid that stacks on mobile

**Header Section:**
- Page title: "Grade Submission"
- Assignment link (blue, clickable)
- Back to submissions button with arrow icon

**Main Grading Form:**
- **Grade Input Field**:
  - Number input with min (0), max (assignment.points), step (1)
  - Visual placeholder showing range
  - Right-aligned text showing "/ max points"
  - Current grade preview if previously graded
  - Live grade preview showing percentage and letter grade
  - Updates in real-time as you type

- **Feedback Textarea**:
  - Large 8-row text area
  - Character counter at bottom
  - "Auto-saves as you type" indicator
  - Placeholder with helpful text

- **Grading Criteria Display** (if available):
  - Blue-tinted box with criteria text
  - Shown above submit buttons for easy reference
  - Whitespace-preserved formatting

- **Success/Error Messages**:
  - Green success banner with checkmark icon
  - Red error banner with X icon
  - Auto-dismisses after 3 seconds (success only)
  - Shows specific error messages from server

- **Submit Buttons**:
  - Cancel button (links back to submissions)
  - "Save Grade & Feedback" primary button (blue)
  - Button disables during submission
  - Text changes to "Saving..."

**Sidebar Information:**
- **Student Info Card**:
  - Circular avatar with initials
  - Full name and email
  - Clean card design

- **Submission Details Card**:
  - Status badges (graded/submitted/late)
  - Submitted timestamp (date + time)
  - Previously graded info (if exists):
    - Date graded
    - Teacher who graded it

- **Submitted Files Card**:
  - List of all submitted documents
  - File icon, filename, file size
  - Individual download button per file
  - Gray background cards with hover effect

#### 3. Vanilla JavaScript Auto-Save (250+ lines)

**Variable Tracking:**
- `lastSavedGrade`: Tracks last saved grade value
- `lastSavedFeedback`: Tracks last saved feedback text
- `autoSaveTimeout`: Debounce timer (1.5 seconds)
- Prevents unnecessary saves when nothing changed

**Live Grade Preview:**
- Calculates percentage as you type
- Shows letter grade (A/B/C/D/F) based on percentage:
  - A: ≥90%, B: ≥80%, C: ≥70%, D: ≥60%, F: <60%
- Validates grade doesn't exceed max points
- Shows warning if grade > max points
- Blue text color for valid preview
- Red text for validation errors

**Character Counter:**
- Updates on every keystroke
- Shows current character count
- No maximum limit (informational only)

**Auto-Save Functionality:**
- Triggers 1.5 seconds after last keystroke (debounced)
- Only saves if values changed from last save
- Validates grade range (0 to max points)
- Uses Fetch API to send PATCH request
- Sends JSON request with CSRF token
- Handles success and error responses
- Updates "Current" grade preview on success
- Shows success/error messages

**Form Submission:**
- Prevents default form submission
- Validates grade is within valid range
- Disables submit button to prevent double-submission
- Changes button text to "Saving..."
- Uses Fetch API for AJAX submission
- Redirects to submissions index after 1.5 seconds on success
- Re-enables button on error

**Message Handling:**
- `showMessage(type, message)` function
- Success messages auto-dismiss after 3 seconds
- Error messages stay until dismissed or corrected
- Updates appropriate banner content

**Event Listeners:**
- `gradeInput.input`: Updates preview + schedules auto-save
- `feedbackInput.input`: Updates char count + schedules auto-save
- `form.submit`: Handles final submission with validation

#### 4. Submission Show View (`app/views/submissions/show.html.erb`)

**Layout Structure:**
- Two-column responsive layout
- Main content (2/3) + Sidebar (1/3)
- Role-based display (teacher vs student)

**Header Section:**
- "Submission Details" title
- Assignment link
- Context-aware back button text

**Grade Display Section:**
- **If Graded**:
  - Three colored cards showing:
    1. Points earned/total (blue)
    2. Percentage (green)
    3. Letter grade (purple)
  - Large, bold numbers for easy reading
  - Grading timestamp and teacher name
  - "Edit Grade" link for teachers

- **If Not Graded**:
  - Empty state with clipboard icon
  - "Not Graded Yet" message
  - Context-aware text (teacher vs student)
  - "Grade Now" button for teachers

**Feedback Section:**
- Shows feedback if provided
- Preserves whitespace and line breaks
- Gray prose styling for readability
- "No feedback provided" message if missing (students only)

**Submitted Files Section:**
- List of all documents with:
  - Large document icon
  - Filename (bold)
  - File size and content type
  - Download button per file (blue)
- Hover effect on file cards
- "Download All Files" button if multiple files (future feature)

**Grading Criteria Section** (if available):
- Shows assignment's grading criteria
- Helps student understand grading
- Whitespace-preserved formatting

**Sidebar Cards:**
- **Student Information**:
  - Avatar with initials
  - Full name and email
  - Title adapts: "Student" for teachers, "Your" for students

- **Submission Status**:
  - Status badge with icon
  - Late submission badge if applicable
  - Submitted timestamp
  - Due date for comparison
  - "Time Late" calculation if late (shows duration)

- **Assignment Details**:
  - Course name
  - Category badge (color-coded)
  - Total points
  - Link to full assignment details

### Technical Highlights:

1. **Auto-Save**: Debounced (1.5s) AJAX saves prevent data loss
2. **Live Preview**: Real-time percentage and letter grade calculation
3. **Dual Response**: Controller supports both HTML and JSON formats
4. **Authorization**: Three-level checks (teacher, owner, assignment creator)
5. **Grade Validation**: Client-side and server-side validation (0 to max)
6. **Character Counter**: Real-time feedback length tracking
7. **Success Feedback**: Visual confirmation with auto-dismiss
8. **Error Handling**: Graceful degradation with helpful messages
9. **Responsive Design**: Two-column desktop, stacked mobile
10. **Role-Based UI**: Different views for teachers vs students
11. **File Management**: Individual downloads with size display
12. **Status Badges**: Color-coded visual indicators throughout
13. **Graded By**: Tracks which teacher graded the submission
14. **Time Calculations**: Shows "time late" with human-readable format
15. **Form Protection**: Prevents double-submission during save

### Testing Notes:

**Access grading page:**
```ruby
# As teacher (assignment creator)
assignment = current_user.assignments.first
submission = assignment.submissions.first
# Navigate to: /assignments/:assignment_id/submissions/:id/edit
```

**Test auto-save:**
1. Start typing in grade input (wait 1.5 seconds)
2. Check for success message
3. Verify grade saved in database:
   ```ruby
   Submission.find(submission_id).grade
   ```

**Test live preview:**
1. Type grade: 90/100 → Should show "90.0% (A)"
2. Type grade: 75/100 → Should show "75.0% (C)"
3. Type grade: 120/100 → Should show warning

**Test feedback:**
1. Type in feedback textarea
2. Watch character count update
3. Wait 1.5 seconds for auto-save
4. Verify in database

**Test form submission:**
1. Fill grade and feedback
2. Click "Save Grade & Feedback"
3. Should redirect to submissions index
4. Verify grade and feedback saved
5. Check graded_at and graded_by set correctly

**Test show page:**
```ruby
# As student
submission = current_user.submissions.first
# Navigate to: /assignments/:assignment_id/submissions/:id

# Should see:
# - Grade display (if graded)
# - Feedback (if provided)
# - Submitted files
# - Submission status
```

**Verify authorization:**
1. ✅ Teacher can only edit their own assignment's submissions
2. ✅ Students cannot access edit page
3. ✅ Students can only view their own submissions
4. ✅ Teachers can view all submissions for their assignments
5. ✅ Unauthorized access redirects with alert

**Database Verification:**
```ruby
submission = Submission.find(submission_id)
submission.grade  # Should have value
submission.feedback  # Should have text
submission.graded_at  # Should be timestamp
submission.graded_by_id  # Should be teacher's ID
submission.graded_by.full_name  # Should show teacher name
submission.status  # Should be "graded"
submission.percentage_grade  # Should calculate correctly
submission.letter_grade  # Should return A/B/C/D/F
```

### Next Steps:
Ready to proceed to **Todo #6: Teacher - Edit/Delete Assignments**

This will involve:
- Edit form already exists (created in Todo #2)
- Enhance delete confirmation with cascade details
- Show what gets deleted: submissions count, files, grades
- Add option to archive instead of delete
- Update authorization checks for edit/delete
- Add edit button to assignment show page
- Improve delete button styling and placement

---

## Todo #6: Teacher Edit/Delete Assignments ✅ COMPLETED

### Date: January 29, 2025

### Changes Made:

#### 1. Controller Enhancements (`app/controllers/assignments_controller.rb`)

**Added Ownership Check Before Action:**
- Added `check_ownership` before_action for edit, update, destroy
- Prevents teachers from modifying other teachers' assignments
- Redirects unauthorized users with clear alert message

**Enhanced Update Action:**
- Added explicit ownership check at start of action
- Returns early with redirect if not owner
- Improved error handling with status: :unprocessable_entity
- Clear success message on successful update

**Enhanced Destroy Action:**
- Added ownership check before deletion
- Captures statistics before deletion:
  - `submissions_count`: Total submissions
  - `graded_count`: Number of graded submissions
- Provides detailed notice message after deletion
- Shows exactly what was deleted (submissions and grades)
- Proper pluralization for submission/grade counts

**New Helper Method:**
- `check_ownership`: Validates current_user owns the assignment
- DRY approach for authorization across edit/update/destroy
- Single point of control for ownership validation

#### 2. Comprehensive Assignment Show View (`app/views/assignments/show.html.erb`)

**Header Section:**
- **Title & Status**:
  - Large assignment title (3xl font)
  - Overdue badge with warning icon if past due
  - Course name, category badge, points, due date in subtitle
  - Color-coded category badges (blue/purple/yellow/red)

- **Action Buttons** (teacher only, if owner):
  - Back button with left arrow
  - Edit button (blue) - links to edit page
  - Delete button (red) - triggers enhanced modal
  - All buttons with hover effects and icons

**Main Content Area (2/3 width):**

1. **Description Card**:
   - White card with shadow
   - Preserves whitespace and formatting
   - Prose styling for readability

2. **Grading Criteria Card** (if available):
   - Shows assignment rubric
   - Whitespace-preserved display
   - Helps students understand expectations

3. **Attached Files Card** (if files exist):
   - List of all assignment files
   - Each file shows:
     - Document icon
     - Filename (truncated if long)
     - File size (human-readable)
     - Content type
     - Download button (blue, with icon)
   - Hover effect on file cards
   - Gray background for distinction

4. **Teacher Actions Card** (teacher owner only):
   - Grid of action buttons:
     - "View Submissions" - shows total count
     - "Edit Assignment" - quick access to edit
   - Large clickable cards with icons
   - Hover effects (blue/green borders)

5. **Student Actions Card** (students only):
   - **If Submitted**:
     - Blue success card with checkmark
     - Shows submission timestamp
     - "View Submission" button
   - **If Not Submitted**:
     - Empty state with warning icon
     - "Not Submitted" message
     - "Submit Assignment" button (blue)

**Sidebar (1/3 width):**

1. **Assignment Details Card**:
   - Due date with time
   - Time remaining/overdue calculation
   - Points value
   - Category badge
   - Course name
   - Resubmission status (if allowed)
   - Created date

2. **Submission Statistics Card** (teacher owner only):
   - Total submissions count
   - Submitted count (green)
   - Graded count (purple)
   - Pending count (yellow)
   - Average grade percentage (blue, if available)
   - Clean list layout with labels

3. **Instructor Info Card**:
   - Circular avatar with initials
   - Instructor full name
   - Email address
   - Same style as submission views

#### 3. Enhanced Delete Confirmation Modal

**Modal Structure:**
- Fixed overlay covering entire screen
- Centered modal with shadow
- Backdrop blur and opacity
- Responsive sizing (max-width lg)
- Smooth transitions

**Modal Content:**
- **Header**:
  - Red warning icon in circle
  - "Delete Assignment" title
  - Clear, prominent display

- **Warning Message**:
  - Shows assignment title being deleted
  - Yellow warning box with border
  - "⚠️ This action cannot be undone!" header
  - Detailed list of consequences:
    - Number of submissions to be deleted
    - Number of graded submissions with feedback
    - Note about permanent file removal

- **Action Buttons**:
  - "Delete Assignment" (red, dangerous action)
  - "Cancel" (gray, safe action)
  - Proper focus rings for accessibility
  - Hover effects on both buttons

**Modal Behavior:**
- Shows when delete button clicked
- Closes on cancel button
- Closes when clicking outside modal
- Updates content dynamically from data attributes
- Prevents accidental deletions

#### 4. Vanilla JavaScript Delete Handler (100+ lines)

**Event Listeners:**
- Delete button click → Opens modal
- Cancel button click → Closes modal
- Outside click → Closes modal
- Confirm button click → Submits delete form

**Dynamic Content Update:**
- Reads data attributes from delete button:
  - `data-assignment-id`: Assignment ID
  - `data-assignment-title`: Title to display
  - `data-submissions-count`: Total submissions
  - `data-graded-count`: Graded count
- Updates modal text content dynamically
- Stores assignment ID for confirmation

**Form Submission:**
- Creates form element dynamically
- Sets method to POST with _method=delete
- Includes CSRF token from meta tag
- Appends form to body
- Submits form programmatically
- No page navigation until confirmed

**Safety Features:**
- Two-step confirmation (click delete, then confirm)
- Clear warning with specific numbers
- Visual distinction (red colors for danger)
- Detailed information about consequences
- Easy to cancel

### Technical Highlights:

1. **Ownership Validation**: Three-level authorization (authenticated, teacher, owner)
2. **Detailed Feedback**: Shows exactly what will be deleted
3. **Statistics Display**: Real-time submission stats for teachers
4. **Role-Based Views**: Different actions for teachers vs students
5. **File Management**: Download individual files with metadata
6. **Modal Pattern**: Reusable confirmation modal with dynamic content
7. **Responsive Design**: Two-column desktop, stacked mobile
8. **Time Calculations**: Shows "due in" or "overdue by" with human format
9. **Visual Hierarchy**: Clear section separation with cards
10. **Status Indicators**: Color-coded badges throughout
11. **Action Cards**: Large, clickable areas for better UX
12. **Empty States**: Helpful messages when no data exists
13. **CSRF Protection**: Proper token handling in AJAX requests
14. **Accessibility**: Semantic HTML, proper ARIA attributes
15. **Error Prevention**: Multiple checks before destructive actions

### Testing Notes:

**Test assignment show page:**
```ruby
# As teacher (owner)
assignment = current_user.assignments.first
# Navigate to: /assignments/:id
# Should see: Edit button, Delete button, Teacher Actions, Statistics
```

**Test edit functionality:**
1. Click Edit button on show page
2. Should navigate to edit form (from Todo #2)
3. Modify assignment details
4. Submit form
5. Should redirect to show page with success notice

**Test delete with modal:**
1. Click Delete button
2. Modal should appear with:
   - Assignment title
   - Submissions count
   - Graded count
   - Warning message
3. Click Cancel → Modal closes
4. Click Delete again
5. Click "Delete Assignment" → Redirects to index with notice

**Test ownership protection:**
```ruby
# As teacher A
assignment = User.find_by(role: 'teacher', id: teacher_b_id).assignments.first
# Try to access: /assignments/:id/edit
# Should redirect with alert: "You can only modify your own assignments."
```

**Test student view:**
```ruby
# As student
assignment = Assignment.first
# Navigate to: /assignments/:id
# Should see:
# - Assignment details
# - Instructor info
# - Submit button (if not submitted)
# - Submission status (if submitted)
# Should NOT see: Edit/Delete buttons, Statistics, Teacher Actions
```

**Database Verification:**
```ruby
# Before deletion
assignment = Assignment.find(assignment_id)
submissions_count = assignment.submissions.count
graded_count = assignment.submissions.graded.count

# Perform deletion via UI

# After deletion
Assignment.find_by(id: assignment_id)  # Should be nil
Submission.where(assignment_id: assignment_id).count  # Should be 0
```

**Test modal behavior:**
1. ✅ Delete button opens modal
2. ✅ Cancel button closes modal
3. ✅ Clicking outside closes modal
4. ✅ Modal shows correct assignment title
5. ✅ Modal shows correct counts
6. ✅ Confirm button submits form
7. ✅ CSRF token included in form
8. ✅ Redirects to index after deletion
9. ✅ Shows detailed notice message

**Test authorization:**
1. ✅ Only assignment owner can see Edit/Delete buttons
2. ✅ Other teachers cannot edit/delete
3. ✅ Students cannot edit/delete
4. ✅ Edit page checks ownership
5. ✅ Update action checks ownership
6. ✅ Destroy action checks ownership
7. ✅ Proper redirects with alerts

### Next Steps:
Ready to proceed to **Todo #7: Student - Assignments Dashboard**

This will involve:
- Replace the placeholder student view from Todo #3
- Show all assignments with comprehensive information
- Add status badges (upcoming/overdue/submitted/graded)
- Implement filters (category, status, course, search)
- Add sorting options
- Display submission status and grades for each assignment
- Show statistics cards (pending, submitted, graded, average grade)
- Use Vanilla JS for filtering/sorting without page reloads
- Mobile-responsive card layout
- Empty states and helpful messages

---

## Todo #7: Student Assignments Dashboard ✅ COMPLETED

### Date: January 29, 2025

### Changes Made:

#### 1. Replaced Student View Partial (`app/views/assignments/_student_view.html.erb`)

**Complete Redesign:**
- Replaced basic placeholder with comprehensive dashboard (400+ lines)
- Professional card-based layout for assignments
- Real-time filtering and sorting with Vanilla JS
- Responsive grid layout (1/2/3 columns based on screen size)

**Header Section:**
- "My Assignments" title with subtitle
- Clean, professional typography
- Consistent with teacher dashboard styling

#### 2. Statistics Cards (4 Cards)

**Dashboard Metrics:**
- **Total Assignments**: Blue border, document icon
  - Shows count of all available assignments
  - Calculates from @assignments collection

- **Pending**: Yellow border, clock icon
  - Assignments not yet submitted
  - Excludes submitted and graded
  - Helps students track what needs attention

- **Submitted**: Green border, checkmark icon
  - Count of submitted assignments (including graded)
  - Shows student's completion progress
  - Includes both submitted and graded status

- **Average Grade**: Purple border, star icon
  - Calculates from graded submissions only
  - Shows percentage average
  - Displays "N/A" if no grades yet
  - Uses percentage_grade method from model

**Calculation Logic:**
```ruby
user_submissions = current_user.submissions.includes(:assignment)
pending = assignments without submission
submitted = submissions count (submitted + graded)
average = sum of percentage_grades / count of graded
```

#### 3. Comprehensive Filter Section

**Four Filter Controls:**

1. **Search Input**:
   - Searches by title OR course name
   - Case-insensitive partial matching
   - Real-time filtering as you type
   - Placeholder: "Search by title or course..."

2. **Category Filter** (Dropdown):
   - All Categories (default)
   - Homework
   - Project
   - Quiz
   - Exam
   - Filters by assignment.category

3. **Status Filter** (Dropdown):
   - All Status (default)
   - Upcoming (not overdue, not submitted)
   - Overdue (past due, not submitted)
   - Submitted (submitted but not graded)
   - Graded (graded submissions)
   - Pending/Not Submitted

4. **Sort Select** (Dropdown):
   - Due Date (Soonest) - default
   - Due Date (Latest)
   - Newest First (by created_at)
   - Oldest First
   - Title A-Z
   - Title Z-A
   - Course A-Z

#### 4. Assignment Cards (Detailed Information)

**Card Structure:**
- White background with shadow
- Hover effect (larger shadow)
- Rounded corners
- Three sections: Header, Body, Footer

**Card Header:**
- Assignment title (clickable link to show page)
- Status badge in top-right:
  - Red "Overdue" (if past due and not submitted)
  - Purple "Graded" (if graded)
  - Green "Submitted" (if submitted but not graded)
- Course name displayed below title

**Card Body:**
- **Category Badge**: Color-coded (blue/purple/yellow/red)
- **Points**: Display assignment total points
- **Due Date**: Full date and time with calendar icon
- **Grade Display** (if graded):
  - Shows: points earned / total points
  - Percentage and letter grade
  - Purple color scheme
  - Separated by border
- **Submission Status** (if submitted):
  - "Submitted: [date and time]"
  - Small text in gray

**Card Footer (Actions):**
- **If Submitted**: Blue "View Submission" button
- **If Overdue**: Gray "View Details" button
- **If Not Submitted**: Green "Submit Assignment" button
- Full-width button with proper styling
- Links to appropriate pages

**Data Attributes for Filtering:**
- `data-title`: Lowercase title for search
- `data-course`: Lowercase course name for search
- `data-category`: Category value
- `data-status`: graded/submitted/overdue/upcoming
- `data-due-date`: Unix timestamp for sorting
- `data-created-at`: Unix timestamp for sorting

#### 5. Vanilla JavaScript Filtering & Sorting (150+ lines)

**Main Function: filterAndSort()**

**Filtering Logic:**
- Search: Checks if title OR course includes search term
- Category: Exact match with assignment.category
- Status: Complex logic:
  - "pending": Neither submitted nor graded
  - "graded": status === 'graded'
  - "submitted": status === 'submitted'
  - "overdue": status === 'overdue'
  - "upcoming": status === 'upcoming'
- AND logic: All active filters must match

**Sorting Logic:**
- Uses Array.sort() with switch statement
- Compares Unix timestamps for dates
- Uses localeCompare() for alphabetical sorting
- Six different sort options
- Maintains filter results while reordering

**DOM Manipulation:**
- Hides all cards first
- Shows only visible cards
- Reorders by appending to grid (maintains sort)
- Updates display property (not removing from DOM)

**Statistics Update:**
- Recalculates based on visible cards only
- Updates total, pending, submitted counts
- Real-time updates as filters change
- Reflects current filtered view

**No Results Handling:**
- Shows "No assignments found" message
- Hides assignments grid when empty
- Displays search icon and helpful text
- Suggests adjusting filters

**Event Listeners:**
- `searchInput`: input event (real-time)
- `categoryFilter`: change event
- `statusFilter`: change event
- `sortSelect`: change event
- All trigger filterAndSort()

#### 6. Empty State

**When No Assignments Exist:**
- Large document icon (gray)
- "No assignments available" heading
- Friendly message: "Check back later for new assignments"
- Centered layout with padding
- White card with shadow

#### 7. Status Calculation Logic

**Determines Card Status:**
```ruby
user_submission = find submission for current_user
is_overdue = assignment.overdue? (past due date)
is_upcoming = not overdue and due_date > now
has_submitted = submission exists
is_graded = submission.status == 'graded'

Final status:
- graded: if is_graded
- submitted: if has_submitted but not graded
- overdue: if is_overdue and not has_submitted
- upcoming: otherwise
```

### Technical Highlights:

1. **Real-time Filtering**: No page reloads, instant results
2. **Multi-criteria Filtering**: Search + 3 filters work together
3. **Dynamic Statistics**: Updates based on filtered view
4. **Smart Status Detection**: Accurate status for each assignment
5. **Grade Display**: Only shown when available
6. **Responsive Grid**: 1/2/3 columns adapts to screen size
7. **Color Coding**: Consistent color scheme throughout
8. **Performance**: Uses data attributes for efficient querying
9. **User Experience**: Clear visual hierarchy and actions
10. **Accessibility**: Semantic HTML, proper labels
11. **Empty States**: Helpful messages for edge cases
12. **Sort Persistence**: Maintains order during filtering
13. **Link Integration**: Connects to submission and assignment pages
14. **Time Display**: Human-readable date formats
15. **Status Badges**: Visual indicators with icons

### Testing Notes:

**Access student dashboard:**
```ruby
# As student
# Navigate to: /assignments
# Should see student view with cards
```

**Test statistics:**
1. ✅ Total shows all assignments
2. ✅ Pending shows unsubmitted count
3. ✅ Submitted shows submitted + graded count
4. ✅ Average calculates correctly from graded submissions
5. ✅ Statistics update when filters applied

**Test filtering:**
```ruby
# Create test data
teacher = User.find_by(role: 'teacher')
student = User.find_by(role: 'student')

# Create assignments with different categories
assignment1 = teacher.assignments.create(
  title: 'Homework 1',
  course_name: 'Math',
  category: 'homework',
  due_date: 2.days.from_now,
  points: 100
)

assignment2 = teacher.assignments.create(
  title: 'Project 1',
  course_name: 'Science',
  category: 'project',
  due_date: 1.day.ago,
  points: 200
)

# Create submission
student.submissions.create(
  assignment: assignment1,
  status: 'submitted'
)
```

**Verify filtering:**
1. ✅ Search by title filters correctly
2. ✅ Search by course name filters correctly
3. ✅ Category filter shows only selected category
4. ✅ Status filter shows correct assignments:
   - Upcoming: future due date, not submitted
   - Overdue: past due date, not submitted
   - Submitted: has submission, not graded
   - Graded: has submission with grade
   - Pending: no submission
5. ✅ Multiple filters work together (AND logic)

**Test sorting:**
1. ✅ Due Date (Soonest): Orders by soonest first
2. ✅ Due Date (Latest): Orders by latest first
3. ✅ Newest First: Orders by created_at desc
4. ✅ Oldest First: Orders by created_at asc
5. ✅ Title A-Z: Alphabetical ascending
6. ✅ Title Z-A: Alphabetical descending
7. ✅ Course A-Z: Course name alphabetical

**Test grade display:**
```ruby
submission = student.submissions.first
submission.update(
  grade: 85,
  status: 'graded'
)
# Refresh page
# Should see: 85/100, 85.0% (B)
```

**Test card actions:**
1. ✅ Not submitted → Green "Submit Assignment" button
2. ✅ Submitted → Blue "View Submission" button
3. ✅ Overdue → Gray "View Details" button
4. ✅ Graded → Blue "View Submission" button (shows grade)

**Test responsive design:**
1. ✅ Desktop: 3 columns
2. ✅ Tablet: 2 columns
3. ✅ Mobile: 1 column
4. ✅ Statistics cards adapt (4 cols → 2 cols → 1 col)
5. ✅ Filters adapt (4 cols → 2 cols → 1 col)

**Test empty states:**
1. ✅ No assignments: Shows empty state
2. ✅ No results from filter: Shows "No assignments found"
3. ✅ Clear difference between two states

### Next Steps:
Ready to proceed to **Todo #8: Student - Submit Assignment**

This will involve:
- Create submission form for students
- Multiple file upload with drag-drop support
- File validation (type, size, duplicates)
- Show assignment details and requirements
- Display due date with warning if late
- Prevent submission if overdue (or show warning)
- Confirmation before submitting
- Success/error feedback
- Use Vanilla JS for file management
- Similar to assignment creation form but simpler
- Redirect to submission show page after success

---

## Todo #8: Student - Submit Assignment ✅

**Status**: COMPLETED
**Date**: October 29, 2025

### Overview:
Created a comprehensive submission form that allows students to submit their assignments with multiple file uploads, drag-and-drop support, validation, and clear feedback. The interface provides all assignment details, warnings for late submissions, and prevents duplicate submissions unless resubmission is allowed.

### Files Modified:

#### 1. `/app/views/submissions/new.html.erb` (600+ lines)
Complete redesign of the submission form with:

**Header Section:**
- Back to assignments link with icon
- Page title (Submit/Resubmit based on context)
- Subtitle describing the action

**Warning Messages:**
```erb
# Already Submitted Warning (if no resubmission allowed)
- Yellow alert with warning icon
- Message stating submission already exists
- Link to view existing submission

# Late Submission Warning (if overdue)
- Red alert with error icon
- Shows due date that was missed
- Warns about potential late penalties
```

**Assignment Details Panel:**
```erb
# Gradient header with white text (blue-600 to blue-700)
- Assignment title (h2, text-2xl)
- 3-column grid with icons:
  1. Course name
  2. Due date (formatted)
  3. Points possible
- Description section (if present)
- Grading criteria section (if present)
```

**File Upload Section:**
```erb
# Hidden file input with multiple files support
- Accepts: .pdf, .doc, .docx, .txt, .jpg, .jpeg, .png, .zip, .rar
- direct_upload: true for Active Storage

# Drag & Drop Zone
- Border-dashed with hover effect
- Upload icon (SVG)
- "Click to browse or drag and drop" text
- File type and size information

# File Preview List
- Shows each selected file with:
  - File icon
  - File name (truncated if long)
  - File size (formatted)
  - Remove button with trash icon
- Empty state: "No files selected"
- File count display
```

**Comments/Notes Section:**
```erb
# Optional textarea
- 4 rows
- Placeholder text
- Gray border with blue focus ring
- Helper text: "This field is optional"
```

**Confirmation Checkbox:**
```erb
# Required before submitting
- Standard checkbox with label
- Confirms student's own work
- Additional text if late: "I understand this is a late submission"
```

**Action Buttons:**
```erb
# Cancel button (gray)
- Links back to assignments index

# Submit button (blue)
- Disabled by default
- Enabled only when files selected AND checkbox checked
- Text changes: "Submit Assignment" or "Resubmit Assignment"
```

**Loading Indicator:**
```erb
# Hidden by default, shown on submit
- Spinning animation
- "Uploading files, please wait..." text
```

**Vanilla JavaScript (300+ lines):**

**File Management:**
```javascript
// Variables
- fileInput: Hidden file input element
- dropZone: Drag-drop area
- selectedFiles: DataTransfer object to track files
- MAX_FILE_SIZE: 10MB
- ALLOWED_TYPES: Array of MIME types

// Event Listeners
1. Browse button click → Opens file picker
2. Drop zone click → Opens file picker
3. File input change → Handles files
4. Drag over → Adds visual feedback
5. Drag leave → Removes visual feedback
6. Drop → Handles dropped files
7. Checkbox change → Updates submit button
8. Form submit → Shows loading indicator

// handleFiles(files) function
- Validates each file:
  1. Check size (max 10MB)
  2. Check file type (allowed extensions)
  3. Check for duplicates (by name and size)
- Adds valid files to DataTransfer
- Updates file input with new files
- Calls updateFileList() and updateSubmitButton()

// updateFileList() function
- Clears current list
- If no files: Shows "No files selected"
- For each file:
  1. Creates file item div with gray background
  2. Shows file icon, name, size
  3. Adds remove button
  4. Attaches remove event listener

// removeFile(index) function
- Creates new DataTransfer without file at index
- Updates file input
- Calls updateFileList() and updateSubmitButton()

// showError(message) function
- Displays error message below drop zone
- Red text color

// formatFileSize(bytes) function
- Converts bytes to readable format
- Returns: "X.XX KB/MB/GB"

// updateSubmitButton() function
- Checks two conditions:
  1. At least one file selected
  2. Confirmation checkbox checked
- Enables submit button only if both true

// Form submit handler
- Final validation before submission
- Shows loading indicator
- Disables submit button during upload
```

#### 2. `/app/controllers/submissions_controller.rb`
Updated `create` action to handle submissions properly:

**Before Create Logic:**
```ruby
# Check for existing submission
existing_submission = @assignment.submissions.find_by(user_id: current_user.id)

# If already submitted and no resubmission allowed
if existing_submission && !@assignment.allow_resubmission
  redirect_to submission show page
  alert: "Already submitted. Resubmissions not allowed."
  return
end
```

**Create/Update Logic:**
```ruby
# If resubmission allowed, update existing
if existing_submission && @assignment.allow_resubmission
  @submission = existing_submission
  @submission.assign_attributes(submission_params)
else
  # Create new submission
  @submission = @assignment.submissions.new(submission_params)
  @submission.user = current_user
end

# Set status and timestamp
@submission.status = 'submitted'
@submission.submitted_at = Time.current
```

**Success/Error Handling:**
```ruby
if @submission.save
  redirect_to assignment_submission_path(@assignment, @submission)
  notice: "Assignment submitted/resubmitted successfully!"
else
  render :new, status: :unprocessable_entity
end
```

**Authorization:**
```ruby
# Added authorize_student! before_action
before_action :authorize_student!, only: [:new, :create]

# New method
def authorize_student!
  if current_user.teacher?
    redirect_to root_path, alert: "Teachers cannot submit assignments."
  end
end
```

**Updated submission_params:**
```ruby
def submission_params
  params.require(:submission).permit(:content, documents: [])
end
# Changed from :status to :content
# Status is now set automatically in controller
```

### Key Features Implemented:

1. **Duplicate Submission Prevention:**
   - Checks for existing submission in controller
   - Shows warning message if already submitted
   - Allows resubmission only if `allow_resubmission` is true
   - Links to existing submission for viewing

2. **Late Submission Handling:**
   - Calculates if assignment is overdue
   - Shows prominent red warning banner
   - Displays original due date
   - Warns about potential penalties
   - Still allows submission (teacher can decide on penalties)

3. **File Upload with Drag & Drop:**
   - Click to browse or drag-drop interface
   - Multiple files support
   - Visual feedback on drag over
   - File preview with icons
   - Individual file removal
   - Real-time file count

4. **File Validation:**
   - Size limit: 10MB per file
   - Allowed types: PDF, DOC, DOCX, TXT, JPG, PNG, ZIP, RAR
   - Duplicate detection (same name + size)
   - Clear error messages for each validation failure
   - Prevents adding invalid files

5. **Assignment Details Display:**
   - Beautiful gradient header with white text
   - Course name, due date, points possible
   - Full description (if provided)
   - Grading criteria (if provided)
   - All information student needs to complete assignment

6. **Confirmation System:**
   - Required checkbox before submission
   - Confirms student's own work
   - Additional late submission acknowledgment
   - Submit button disabled until confirmed

7. **Optional Comments:**
   - Text area for student notes/comments
   - Not required, clearly marked optional
   - Useful for explaining approach or issues

8. **Loading State:**
   - Spinner animation during upload
   - "Uploading files, please wait..." message
   - Submit button disabled during upload
   - Prevents double submissions

9. **Authorization:**
   - Students only can access submit form
   - Teachers redirected with error message
   - Existing submission check
   - Resubmission permission check

10. **User Experience:**
    - Clean, professional design
    - Responsive layout
    - Clear visual hierarchy
    - Helpful error messages
    - Success feedback
    - Cancel option always available

### Technical Highlights:

1. **DataTransfer API**: Used for managing multiple files efficiently
2. **File Validation**: Client-side validation before upload
3. **Drag & Drop Events**: dragover, dragleave, drop
4. **Visual Feedback**: Border and background color changes
5. **Dynamic UI**: Real-time updates as files added/removed
6. **File Size Formatting**: Human-readable file sizes
7. **SVG Icons**: Inline SVG for upload, file, trash icons
8. **Tailwind Classes**: Responsive, hover, focus states
9. **Active Storage**: Multiple file attachments with direct upload
10. **Form State Management**: Enable/disable based on validation
11. **Error Handling**: Both client and server-side validation
12. **Redirect Logic**: Smart routing based on success/failure
13. **Status Management**: Automatic status and timestamp setting
14. **Resubmission Logic**: Handle both new and updated submissions
15. **Authorization Guards**: Prevent unauthorized access

### Testing Notes:

**Test as student without existing submission:**
```ruby
# 1. Navigate to assignment show page
assignment = Assignment.first
visit assignment_path(assignment)

# 2. Click "Submit Assignment" button
click_link "Submit Assignment"

# 3. Verify form elements visible
expect(page).to have_content("Submit Assignment")
expect(page).to have_content(assignment.title)
expect(page).to have_content(assignment.course_name)

# 4. Try submitting without files
# - Submit button should be disabled
# - Cannot submit until files added

# 5. Add files via drag-drop or browse
# - Files should appear in preview list
# - File count updates

# 6. Try adding invalid file (too large or wrong type)
# - Error message should appear
# - File not added to list

# 7. Add valid file
# - File appears in list with size
# - Submit button still disabled (need checkbox)

# 8. Check confirmation checkbox
# - Submit button now enabled

# 9. Submit form
# - Loading indicator appears
# - Redirects to submission show page
# - Success message appears

# 10. Verify submission in database
submission = Submission.last
expect(submission.status).to eq('submitted')
expect(submission.submitted_at).to be_present
expect(submission.documents).to be_attached
```

**Test with existing submission (no resubmission allowed):**
```ruby
# 1. Create existing submission
submission = assignment.submissions.create!(
  user: student,
  status: 'submitted',
  submitted_at: Time.current
)

# 2. Try to access new submission page
visit new_assignment_submission_path(assignment)

# 3. Verify warning appears
expect(page).to have_content("Already Submitted")
expect(page).to have_content("Resubmissions are not allowed")

# 4. Verify submit form NOT visible
expect(page).not_to have_button("Submit Assignment")

# 5. Verify link to view submission
expect(page).to have_link("View your submission")
```

**Test late submission:**
```ruby
# 1. Create overdue assignment
assignment.update!(due_date: 1.day.ago)

# 2. Access submission form
visit new_assignment_submission_path(assignment)

# 3. Verify late warning appears
expect(page).to have_content("Late Submission Warning")
expect(page).to have_content("This assignment was due")

# 4. Verify can still submit
# - Form should be visible and functional
# - Additional confirmation text in checkbox

# 5. Submit assignment
# - Should succeed despite being late
# - Teacher can apply penalties manually
```

**Test resubmission allowed:**
```ruby
# 1. Enable resubmission
assignment.update!(allow_resubmission: true)

# 2. Create existing submission
submission = assignment.submissions.create!(
  user: student,
  status: 'submitted',
  submitted_at: 2.days.ago
)
submission.documents.attach(...)

# 3. Access submission form
visit new_assignment_submission_path(assignment)

# 4. Verify form appears (not warning)
expect(page).to have_content("Resubmit Assignment")

# 5. Submit new files
# - Should update existing submission
# - New submitted_at timestamp
# - New files attached (replaces old ones)

# 6. Verify in database
submission.reload
expect(submission.submitted_at).to be > 1.day.ago
expect(submission.documents.count).to eq(new_count)
```

**Test teacher access prevention:**
```ruby
# 1. Sign in as teacher
sign_in teacher

# 2. Try to access student submission form
visit new_assignment_submission_path(assignment)

# 3. Verify redirect
expect(current_path).to eq(root_path)
expect(page).to have_content("Teachers cannot submit assignments")
```

**Test file validation:**
```ruby
# Via JavaScript tests or feature specs
# 1. Try 15MB file → Error: "too large"
# 2. Try .exe file → Error: "not allowed type"
# 3. Try same file twice → Error: "already added"
# 4. Try valid files → Success, added to list
# 5. Remove file → Removed from list, count updated
```

### Database Verification:

```ruby
# Check submission created correctly
submission = Submission.last
submission.user_id              # => student.id
submission.assignment_id        # => assignment.id
submission.status               # => "submitted"
submission.submitted_at         # => Time.current (within seconds)
submission.content              # => "Optional comments..." (if provided)
submission.documents.attached?  # => true
submission.documents.count      # => number of files uploaded

# Check files stored correctly
submission.documents.each do |doc|
  doc.filename        # => original filename
  doc.content_type    # => MIME type
  doc.byte_size       # => file size in bytes
  doc.key             # => Active Storage key
end
```

### Next Steps:
Ready to proceed to **Todo #9: Student - View Grades & Feedback**

This will involve:
- Enhance submission show page for student view
- Display grade with percentage and letter
- Show teacher feedback
- Display grading timestamp and teacher name
- Download submitted files
- View grading criteria used
- Different view than teacher's show page
- Back to assignments link
- Resubmit button if allowed

---

## Todo #9: Student - View Grades & Feedback ✅

**Status**: COMPLETED
**Date**: October 29, 2025

### Overview:
Enhanced the submission show page to provide students with a comprehensive view of their submission, grades, feedback, and files. The page now features role-based content, visual status banners, performance insights, and an improved file management interface with both view and download options.

### Files Modified:

#### 1. `/app/views/submissions/show.html.erb` (Enhanced ~450 lines)
Complete redesign of the submission show page with role-based views:

**Header Section (Enhanced):**
```erb
# Role-based title
- Teacher: "Submission Details"
- Student: "Your Submission"

# Action Buttons
- Back button → Routes to assignments (student) or submissions (teacher)
- Resubmit button → Shows if allow_resubmission && not graded (student only)

# Status Banner (Student Only)
Three banner types based on status:
1. Graded (Green gradient):
   - "Your assignment has been graded!"
   - Shows grading date and teacher name
   
2. Late Submission (Yellow gradient):
   - "Late Submission" warning
   - Shows time late (e.g., "3 days after the due date")
   
3. Submitted (Blue gradient):
   - "Submission Received"
   - "Pending review" message
```

**Grade Section:**
```erb
# If graded:
- 3-column grid with cards:
  1. Points: X/Y (blue background)
  2. Percentage: X.X% (green background)
  3. Letter Grade: A/B/C/etc (purple background)
- Grading timestamp
- Graded by: Teacher name

# If not graded:
- Empty state with clipboard icon
- "Not Graded Yet" message
- Role-based description
- "Grade Now" button (teacher only)
```

**Feedback Section:**
```erb
# If feedback present:
- Heading: "Feedback" (teacher) / "Feedback" (student)
- Feedback text in prose format
- Preserves whitespace with whitespace-pre-wrap

# If graded but no feedback:
- Shows "No feedback provided" (student only)
- Hidden for teachers if no feedback
```

**Your Comments Section (NEW):**
```erb
# If student added comments during submission:
- Heading: "Student Comments" (teacher) / "Your Comments" (student)
- Blue-bordered callout box
- Displays submission.content field
- Preserves formatting
```

**Submitted Files Section (Enhanced):**
```erb
# Header with file count badge
- Shows total number of files
- Role-based heading

# File List:
Each file displays:
- Dynamic icon color based on type:
  - PDF: red
  - Word: blue
  - Image: green
  - Zip: yellow
  - Other: gray
- Filename (truncated if long)
- File size (human-readable)
- File type (uppercase extension)
- "Primary" badge on first file (if multiple)

# Actions per file:
1. View button (opens in new tab)
   - Opens file inline in browser
   - Gray button with eye icon
   
2. Download button
   - Downloads file directly
   - Blue button with download icon

# Download All Button (if multiple files):
- Centered at bottom
- Shows total file count
- Uses Vanilla JS to download all files
- 300ms delay between downloads to avoid browser blocking
```

**Download All Vanilla JavaScript:**
```javascript
document.addEventListener('DOMContentLoaded', function() {
  const downloadAllBtn = document.getElementById('download-all-btn');
  if (downloadAllBtn) {
    downloadAllBtn.addEventListener('click', function() {
      // Get all download links
      const links = document.querySelectorAll('a[href*="rails/active_storage"][href*="disposition=attachment"]');
      
      // Download each with delay
      links.forEach((link, index) => {
        setTimeout(() => {
          link.click();
        }, index * 300); // 300ms delay
      });
    });
  }
});
```

**Grading Criteria Section (Enhanced):**
```erb
# If assignment has grading criteria:
- Role-based heading:
  - Teacher: "Grading Criteria"
  - Student: "How You Were Graded"
- Gray bordered box with criteria text
- Preserves formatting
```

**Performance Insights (NEW - Student Only):**
```erb
# Shows only if student && graded
# Gradient indigo/blue background with border

# Two-column grid:
1. Score Achieved:
   - Large percentage display
   - Progress bar showing percentage visually
   - Indigo color scheme

2. Grade Level:
   - Large letter grade display
   - Color coded:
     - A: Green (Excellent work!)
     - B: Blue (Good job!)
     - C: Yellow (Satisfactory)
     - D/F: Red (Needs improvement)
   - Motivational message
```

**Sidebar Information:**

**Student Info Card:**
```erb
# Shows student avatar (initials) and details
- Role-based heading
- Circular avatar with initials
- Student full name
- Student email
```

**Submission Status Card:**
```erb
# Status badges:
- Graded: Purple badge with checkmark
- Submitted: Green badge with checkmark
- Pending: Gray badge
- Late Submission: Red badge (additional)

# Information displayed:
- Submitted At: Full date + time
- Due Date: Full date + time
- Time Late: Duration (if late)
```

**Assignment Details Card:**
```erb
# Assignment information:
- Course name
- Category badge (color-coded):
  - Homework: Blue
  - Project: Purple
  - Quiz: Yellow
  - Exam: Red
- Total Points
- Link to assignment details page
```

### Key Features Implemented:

1. **Role-Based Content:**
   - Different headings for teachers vs students
   - Student-specific status banners
   - Student-specific performance insights
   - Resubmit button only for students
   - Grade Now button only for teachers

2. **Visual Status Communication:**
   - Three gradient banners (graded/late/submitted)
   - Color-coded to convey status instantly
   - Icons for visual reinforcement
   - Contextual messages

3. **Enhanced File Management:**
   - Dynamic icon colors by file type
   - Both View and Download options
   - Primary file indicator
   - File count badge
   - Download all functionality
   - Empty state handling

4. **Performance Insights (Student Feature):**
   - Visual progress bar showing percentage
   - Color-coded letter grades
   - Motivational messages
   - Clean gradient design
   - Two-column responsive layout

5. **Student Comments Display:**
   - Shows optional comments added during submission
   - Blue callout box for emphasis
   - Role-based heading
   - Preserves formatting

6. **Improved Grade Display:**
   - Three separate cards for clarity
   - Color-coded backgrounds
   - Large, readable numbers
   - Grading metadata below

7. **Better Feedback Section:**
   - Clear heading
   - Formatted text display
   - Handles missing feedback gracefully
   - Shows "No feedback provided" for students

8. **Grading Criteria Context:**
   - Role-appropriate heading
   - Boxed display for emphasis
   - Helps students understand their grade

9. **Download All Feature:**
   - Vanilla JavaScript implementation
   - Sequential downloads with delay
   - Prevents browser popup blocking
   - Shows total file count
   - Clean, centered button

10. **Responsive Design:**
    - Mobile-friendly layouts
    - Flexible grids
    - Collapsible sections
    - Touch-friendly buttons

### Technical Highlights:

1. **Conditional Rendering**: Extensive use of conditionals for role-based content
2. **Gradient Backgrounds**: Modern gradient designs for status banners
3. **Dynamic Colors**: File type-based icon coloring
4. **SVG Icons**: Inline SVG for all icons (performance, scalability)
5. **Progress Bar**: CSS-based visual percentage display
6. **Vanilla JavaScript**: Simple, efficient download all functionality
7. **Pluralize Helper**: Proper file count display
8. **Time Formatting**: Readable date/time with strftime
9. **Distance Helper**: Human-readable time differences for late submissions
10. **Number Helpers**: File size formatting (KB, MB, GB)
11. **Active Storage URLs**: Both inline and attachment dispositions
12. **Tailwind Responsive**: Grid layouts adapt to screen size
13. **Empty States**: Graceful handling of missing data
14. **Status Badges**: Reusable badge components with icons
15. **Link Targets**: New tab for file viewing

### Testing Notes:

**Test as student with graded submission:**
```ruby
# 1. Create graded submission
submission = assignment.submissions.create!(
  user: student,
  status: 'graded',
  grade: 85,
  feedback: "Great work! Well organized.",
  content: "I worked hard on this assignment.",
  submitted_at: 2.days.ago,
  graded_at: Time.current,
  graded_by: teacher
)
submission.documents.attach(...)

# 2. Visit show page
visit assignment_submission_path(assignment, submission)

# 3. Verify green "Graded" banner appears
expect(page).to have_content("Your assignment has been graded!")

# 4. Verify grade display
expect(page).to have_content("85/100")
expect(page).to have_content("85.0%")
expect(page).to have_content("B")

# 5. Verify feedback shows
expect(page).to have_content("Great work!")

# 6. Verify student comments show
expect(page).to have_content("Your Comments")
expect(page).to have_content("I worked hard")

# 7. Verify files list
expect(page).to have_button("View")
expect(page).to have_button("Download")

# 8. Verify performance insights
expect(page).to have_content("Performance Summary")
expect(page).to have_content("Score Achieved")
expect(page).to have_content("Good job!")

# 9. Verify grading criteria
expect(page).to have_content("How You Were Graded")

# 10. No resubmit button (graded)
expect(page).not_to have_link("Resubmit Assignment")
```

**Test as student with pending submission:**
```ruby
# 1. Create pending submission
submission = assignment.submissions.create!(
  user: student,
  status: 'submitted',
  submitted_at: Time.current
)

# 2. Visit show page
visit assignment_submission_path(assignment, submission)

# 3. Verify blue "Submitted" banner
expect(page).to have_content("Submission Received")
expect(page).to have_content("pending review")

# 4. Verify "Not Graded Yet" section
expect(page).to have_content("Not Graded Yet")
expect(page).to have_content("pending grading")

# 5. No performance insights (not graded)
expect(page).not_to have_content("Performance Summary")

# 6. Resubmit button if allowed
if assignment.allow_resubmission
  expect(page).to have_link("Resubmit Assignment")
end
```

**Test as student with late submission:**
```ruby
# 1. Create late submission
assignment.update!(due_date: 3.days.ago)
submission = assignment.submissions.create!(
  user: student,
  status: 'submitted',
  submitted_at: Time.current
)

# 2. Visit show page
visit assignment_submission_path(assignment, submission)

# 3. Verify yellow "Late" banner
expect(page).to have_content("Late Submission")
expect(page).to have_content("after the due date")

# 4. Verify late badge in sidebar
expect(page).to have_content("Late Submission", count: 2)

# 5. Verify time late calculation
expect(page).to have_content("Time Late")
expect(page).to have_content("3 days")
```

**Test file download all functionality:**
```ruby
# 1. Create submission with 3 files
submission.documents.attach([file1, file2, file3])

# 2. Visit page
visit assignment_submission_path(assignment, submission)

# 3. Verify download all button
expect(page).to have_button("Download All Files (3)")

# 4. Test JavaScript functionality
# (Use Capybara with JS driver)
click_button "Download All Files (3)"

# 5. Wait for downloads to trigger
# (Verify in browser downloads or mock)
sleep 1

# 6. Each file should be downloaded
# (3 files × 300ms = ~1 second total)
```

**Test view vs download buttons:**
```ruby
# 1. Click "View" button
click_link "View", match: :first

# 2. Verify opens in new tab
# (window.target = "_blank")

# 3. Verify URL has disposition=inline
expect(current_url).to include("disposition=inline")

# 4. Click "Download" button
click_link "Download", match: :first

# 5. Verify downloads file
# (disposition=attachment triggers download)
```

**Test as teacher viewing student submission:**
```ruby
# 1. Sign in as teacher
sign_in teacher

# 2. Visit student submission
visit assignment_submission_path(assignment, submission)

# 3. Verify teacher headings
expect(page).to have_content("Submission Details")
expect(page).to have_content("Student Information")

# 4. No status banner (teacher-specific)
expect(page).not_to have_content("Your assignment has been graded")

# 5. No performance insights (student-only)
expect(page).not_to have_content("Performance Summary")

# 6. No resubmit button (teacher)
expect(page).not_to have_link("Resubmit Assignment")

# 7. Has edit grade link (if graded)
if submission.grade
  expect(page).to have_link("Edit Grade")
end

# 8. Has grade now button (if not graded)
unless submission.grade
  expect(page).to have_link("Grade Now")
end
```

**Test responsive design:**
```ruby
# Mobile view (320px width)
page.driver.resize(320, 568)
visit assignment_submission_path(assignment, submission)

# 1. Grade cards stack vertically
# 2. File actions stack below file info
# 3. Sidebar moves below main content
# 4. Performance grid becomes single column

# Tablet view (768px width)
page.driver.resize(768, 1024)
# 1. Grade cards in row
# 2. Performance grid in two columns
# 3. Sidebar still below main

# Desktop view (1280px width)
page.driver.resize(1280, 800)
# 1. Sidebar beside main content
# 2. All grids at full width
# 3. Optimal spacing
```

### Database Verification:

```ruby
# Check submission data
submission = Submission.find(id)
submission.grade                # => 85.0
submission.percentage_grade     # => 85.0
submission.letter_grade         # => "B"
submission.feedback             # => "Great work! Well organized."
submission.content              # => "I worked hard on this assignment."
submission.status               # => "graded"
submission.submitted_at         # => 2 days ago
submission.graded_at            # => Just now
submission.graded_by            # => teacher user object
submission.late_submission?     # => true/false
submission.documents.count      # => 3

# Check assignment data
assignment = submission.assignment
assignment.title                # => "Essay Assignment"
assignment.course_name          # => "English 101"
assignment.points               # => 100
assignment.category             # => "homework"
assignment.grading_criteria     # => "Criteria text..."
assignment.allow_resubmission   # => true/false
assignment.due_date             # => Date/time
```

### User Experience Improvements:

1. **Clear Visual Hierarchy**: Banners → Grades → Feedback → Files → Criteria
2. **Status at a Glance**: Color-coded banners immediately convey status
3. **Actionable Information**: Download/view buttons prominently placed
4. **Performance Context**: Insights help students understand their grade
5. **Mobile-Friendly**: All elements adapt to small screens
6. **Loading Feedback**: Download all shows action is processing
7. **Empty States**: Graceful messaging when data missing
8. **Consistent Design**: Matches rest of application styling
9. **Accessibility**: Clear labels, semantic HTML, SVG with titles
10. **Professional Polish**: Gradients, shadows, rounded corners

### Next Steps:
**Phase 1 COMPLETE!** All 9 assignment management todos finished! 🎉

Ready to proceed to **Phase 2: Schedule Management** (Todos #10-15) when approved:

**Todo #10: Schedule Management - Database Schema**
- Create schedules table (course, day_of_week, start_time, end_time, room, instructor_id)
- Create schedule_participants junction table (many-to-many with users)
- Add Schedule and ScheduleParticipant models
- Validations and associations
- Scopes for querying schedules

**Future Enhancements for Assignment System:**
- Email notifications when assignments graded
- Bulk download as ZIP for multiple files
- File preview inline (PDF viewer)
- Assignment templates for teachers
- Rubric-based grading
- Peer review assignments
- Group assignments
- Draft submissions
- Assignment analytics dashboard

---

## Todo #10: Schedule Management - Database Schema ✅

**Status**: COMPLETED
**Date**: October 30, 2025

### Overview:
Created comprehensive database schema for schedule management system with schedules table and schedule_participants junction table. Enhanced the existing Schedule model with validations, associations, scopes, and helper methods. Set up many-to-many relationships between users and schedules through the junction table.

### Database Migrations Created:

#### 1. **EnhanceSchedulesTable Migration** (`20251030113554`)
Enhanced existing schedules table with new columns:

```ruby
# Columns added:
- course: string (required)
- day_of_week: integer (0-6, Sunday-Saturday)
- room: string (classroom/location)
- instructor_id: integer (references users table)
- recurring: boolean (default: true)
- color: string (default: '#3B82F6' - blue)

# Indexes added:
- index on instructor_id
- index on day_of_week
- composite index on [day_of_week, start_time] for efficient queries
```

**Existing columns retained:**
- id, title, description, start_time, end_time, user_id, created_at, updated_at

#### 2. **CreateScheduleParticipants Migration** (`20251030113700`)
Created junction table for many-to-many relationship:

```ruby
# Columns:
- id: primary key
- schedule_id: references schedules (required)
- user_id: references users (required)
- role: string (default: 'student')
- active: boolean (default: true)
- created_at, updated_at: timestamps

# Indexes:
- index on schedule_id (from references)
- index on user_id (from references)
- unique composite index on [schedule_id, user_id] (prevents duplicates)

# Foreign Keys:
- schedule_id → schedules table (cascades on delete)
- user_id → users table (cascades on delete)
```

### Models Created/Enhanced:

#### 1. **ScheduleParticipant Model** (NEW)
Complete junction table model with validations:

```ruby
class ScheduleParticipant < ApplicationRecord
  # Associations
  belongs_to :schedule
  belongs_to :user

  # Validations
  validates :schedule_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { 
    scope: :schedule_id, 
    message: "is already enrolled in this schedule" 
  }
  validates :role, inclusion: { 
    in: %w[student teacher], 
    message: "%{value} is not a valid role" 
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :students, -> { where(role: 'student') }
  scope :teachers, -> { where(role: 'teacher') }

  # Ransack configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id schedule_id user_id role active created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[schedule user].freeze
  end
end
```

**Key Features:**
- Prevents duplicate enrollments (unique constraint)
- Role-based participation (student/teacher)
- Active/inactive status for soft deletes
- Scopes for filtering by status and role

#### 2. **Schedule Model** (ENHANCED)
Comprehensive model with full schedule management capabilities:

**Associations:**
```ruby
belongs_to :user                    # Creator
belongs_to :instructor              # Teacher/instructor (optional)
has_many :schedule_participants     # Junction records
has_many :participants              # All enrolled users
has_many :students                  # Only students (filtered)
```

**Validations:**
```ruby
- title: required, max 255 characters
- course: required
- day_of_week: required, 0-6 (enum)
- start_time: required
- end_time: required, must be after start_time
- room: required
- Custom: no time conflicts for same instructor
```

**Enums:**
```ruby
enum :day_of_week, {
  sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
  thursday: 4, friday: 5, saturday: 6
}, prefix: true
```

**Scopes:**
```ruby
scope :for_day, ->(day) { where(day_of_week: day) }
scope :for_instructor, ->(id) { where(instructor_id: id) }
scope :recurring, -> { where(recurring: true) }
scope :by_start_time, -> { order(:start_time) }
scope :by_day_and_time, -> { order(:day_of_week, :start_time) }
scope :active, -> { where('end_time >= ?', Time.current) }
```

**Instance Methods:**
```ruby
# Display methods
def day_name
  Date::DAYNAMES[day_of_week]
end

def formatted_time_range
  "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
end

def duration_in_minutes
  ((end_time - start_time) / 60).to_i
end

def duration_in_hours
  (duration_in_minutes / 60.0).round(1)
end

# Conflict detection
def conflicts_with?(other_schedule)
  return false if day_of_week != other_schedule.day_of_week
  return false if instructor_id != other_schedule.instructor_id
  
  # Check time range overlap
  (start_time < other_schedule.end_time) && 
  (end_time > other_schedule.start_time)
end

# Participant management
def participant_count
  schedule_participants.active.count
end

def student_count
  schedule_participants.active.students.count
end

def add_participant(user, role: 'student')
  schedule_participants.create(user: user, role: role)
end

def remove_participant(user)
  schedule_participants.find_by(user: user)&.destroy
end

def has_participant?(user)
  schedule_participants.exists?(user: user)
end
```

**Custom Validations:**
```ruby
def end_time_after_start_time
  if end_time <= start_time
    errors.add(:end_time, "must be after start time")
  end
end

def no_time_conflicts
  conflicting = Schedule.where(
    instructor_id: instructor_id, 
    day_of_week: day_of_week
  ).where.not(id: id)
   .where('start_time < ? AND end_time > ?', end_time, start_time)
  
  if conflicting.exists?
    errors.add(:base, "Schedule conflicts with another class...")
  end
end
```

#### 3. **User Model** (ENHANCED)
Added schedule-related associations:

```ruby
# New associations
has_many :created_schedules,    # Schedules user created
  class_name: 'Schedule', 
  foreign_key: 'user_id'

has_many :instructed_schedules, # Schedules user teaches
  class_name: 'Schedule', 
  foreign_key: 'instructor_id'

has_many :schedule_participants # Junction records
has_many :enrolled_schedules,   # Schedules enrolled in
  through: :schedule_participants, 
  source: :schedule

# Updated ransackable_associations
def self.ransackable_associations(auth_object = nil)
  %w[... created_schedules instructed_schedules 
     schedule_participants enrolled_schedules].freeze
end
```

### Database Schema Summary:

**schedules table (14 columns):**
```
id                  bigint      primary key
title               string      required
description         text        optional
course              string      required (new)
day_of_week         integer     0-6, required (new)
start_time          datetime    required
end_time            datetime    required
room                string      required (new)
user_id             bigint      foreign key (creator)
instructor_id       bigint      foreign key (new)
recurring           boolean     default: true (new)
color               string      default: '#3B82F6' (new)
created_at          datetime
updated_at          datetime

Indexes:
- index_schedules_on_user_id
- index_schedules_on_instructor_id (new)
- index_schedules_on_day_of_week (new)
- index_schedules_on_day_of_week_and_start_time (new)
```

**schedule_participants table (7 columns):**
```
id                  bigint      primary key
schedule_id         bigint      required, foreign key
user_id             bigint      required, foreign key
role                string      default: 'student'
active              boolean     default: true
created_at          datetime
updated_at          datetime

Indexes:
- index_schedule_participants_on_schedule_id
- index_schedule_participants_on_user_id
- index_schedule_participants_unique (schedule_id, user_id)

Foreign Keys:
- schedule_id references schedules (on_delete: cascade)
- user_id references users (on_delete: cascade)
```

### Key Features Implemented:

1. **Day of Week Enum**: Integer-based enum (0-6) with named methods
2. **Conflict Detection**: Validates no overlapping times for same instructor
3. **Many-to-Many Relationship**: Clean junction table design
4. **Unique Enrollment Constraint**: Prevents duplicate enrollments
5. **Role-Based Participation**: Supports students and teachers
6. **Active Status**: Soft delete capability for participants
7. **Recurring Schedules**: Boolean flag for weekly classes
8. **Color Coding**: Visual customization for calendar views
9. **Efficient Queries**: Strategic indexes on common query patterns
10. **Helper Methods**: Duration, formatting, participant management
11. **Scopes**: Pre-defined queries for common filters
12. **Cascade Deletes**: Proper cleanup of related records
13. **Time Validation**: Ensures end time after start time
14. **Ransack Support**: Full search capability for admin panel
15. **Association Methods**: add_participant, remove_participant, has_participant?

### Testing Commands:

**Verify schema:**
```bash
rails runner "
  puts 'Schedule columns: '
  puts Schedule.column_names.inspect
  puts '\nScheduleParticipant columns: '
  puts ScheduleParticipant.column_names.inspect
"
```

**Test model creation:**
```ruby
# Create a teacher
teacher = User.find_by(role: 'teacher')

# Create a schedule
schedule = Schedule.create!(
  title: 'Introduction to Computer Science',
  description: 'Fundamentals of CS',
  course: 'CS101',
  day_of_week: 1, # Monday
  start_time: Time.current.change(hour: 9, min: 0),
  end_time: Time.current.change(hour: 10, min: 30),
  room: 'Room 205',
  user_id: teacher.id,
  instructor_id: teacher.id,
  recurring: true,
  color: '#3B82F6'
)

# Add students to schedule
student1 = User.find_by(role: 'student')
schedule.add_participant(student1, role: 'student')

# Check participant count
schedule.participant_count # => 1
schedule.student_count     # => 1

# Check for conflicts
schedule.conflicts_with?(other_schedule) # => true/false

# Get day name
schedule.day_name          # => "Monday"
schedule.formatted_time_range # => "09:00 AM - 10:30 AM"
schedule.duration_in_hours # => 1.5
```

**Test associations:**
```ruby
# User associations
teacher.instructed_schedules # Schedules teaching
student.enrolled_schedules   # Schedules enrolled in

# Schedule associations
schedule.participants # All enrolled users
schedule.students     # Only students
schedule.instructor   # Teacher object

# ScheduleParticipant queries
ScheduleParticipant.active.students
ScheduleParticipant.where(schedule: schedule)
```

**Test validations:**
```ruby
# Test unique enrollment
schedule.add_participant(student1) # First time: OK
schedule.add_participant(student1) # Second time: Validation error

# Test time conflict
schedule2 = Schedule.new(
  instructor_id: teacher.id,
  day_of_week: 1, # Same day
  start_time: Time.current.change(hour: 10, min: 0),
  end_time: Time.current.change(hour: 11, min: 0)
  # ...other fields
)
schedule2.valid? # => false (conflicts with schedule)

# Test enum
schedule.day_of_week_monday? # => true
schedule.day_of_week = :friday
schedule.day_of_week_friday? # => true
```

### Technical Highlights:

1. **Composite Indexes**: Optimized for common query patterns
2. **Enum with Prefix**: Prevents method name collisions
3. **Optional Belongs_to**: instructor can be nil during creation
4. **Through Associations**: Clean access to enrolled schedules
5. **Dependent Destroy**: Automatic cleanup of participants
6. **Scope Chaining**: Combine scopes for complex queries
7. **Custom Validation**: Business logic enforcement
8. **Foreign Key Constraints**: Database-level integrity
9. **Unique Constraint**: Prevents data duplication
10. **Default Values**: Sensible defaults for new records
11. **Time Comparison**: Proper datetime handling
12. **Flexible Associations**: Multiple relationship types
13. **Ransack Configuration**: Search and filter support
14. **Role Validation**: Ensures valid participant roles
15. **Active Status**: Soft delete without data loss

### Next Steps:
Ready to proceed to **Todo #11: Teacher - Create Schedule**

This will involve:
- Create SchedulesController with CRUD actions
- Build schedule creation form
- Course name input with autocomplete
- Day of week dropdown
- Time pickers for start/end times
- Room input
- Student multi-select with search
- Conflict detection and warnings
- Color picker for calendar display
- Use Vanilla JS for:
  - Time validation
  - Student selection interface
  - Conflict checking
  - Form submission handling

---

## Todo #11: Teacher - Create Schedule ✅ COMPLETED

### Date: January 31, 2025

### Changes Made:

#### 1. Enhanced SchedulesController (`app/controllers/schedules_controller.rb`)

**Complete Rewrite - From 30 lines to 200+ lines**

**New Actions:**
- `index` - Role-based schedule listing (teacher vs student views)
- `show` - Display schedule with enrolled students
- `new` - Initialize new schedule with current user as instructor
- `create` - Create schedule with student enrollment and conflict detection
- `edit` - Edit existing schedule with enrolled students
- `update` - Update schedule and sync student participants
- `destroy` - Delete schedule and all enrollments
- `check_conflicts_ajax` - AJAX endpoint for real-time conflict checking

**Authorization Methods:**
- `authorize_teacher!` - Ensures only teachers can create/edit/delete schedules
- `authorize_schedule_access!` - Controls access based on role and ownership

**Helper Methods:**
- `add_students_to_schedule(schedule, student_ids)` - Bulk enroll students
- `update_students_in_schedule(schedule, student_ids)` - Sync participants
- `check_conflicts(schedule)` - Validate no time conflicts exist
- `find_conflicting_schedules(schedule)` - Find overlapping schedules

**Key Features:**
1. **Role-Based Index:**
   - Teachers: See created and instructed schedules
   - Students: See enrolled schedules only

2. **Conflict Detection:**
   - Checks for overlapping times on same day
   - Validates against instructor's other schedules
   - Displays warnings before saving
   - AJAX endpoint for real-time validation

3. **Student Enrollment:**
   - Bulk add students during creation
   - Update student list during editing
   - Removes students not in new list
   - Creates ScheduleParticipant records

4. **Error Handling:**
   - Re-renders form with errors
   - Preserves user input on failure
   - Shows validation messages
   - Highlights conflict warnings

**Strong Parameters:**
```ruby
params.require(:schedule).permit(
  :title, :description, :course, :day_of_week,
  :start_time, :end_time, :room, :instructor_id,
  :recurring, :color, student_ids: []
)
```

#### 2. Schedule Form Partial (`app/views/schedules/_form.html.erb`)

**Comprehensive 400+ Line Form**

**Form Fields (10 total):**
1. **Title** - Text input, required
2. **Course** - Text input with placeholder, required
3. **Day of Week** - Select dropdown (Sunday-Saturday), required
4. **Room** - Text input (e.g., "Room 205"), required
5. **Start Time** - Time picker, required
6. **End Time** - Time picker, required
7. **Description** - Textarea, optional
8. **Color** - Color picker (default: #3B82F6)
9. **Recurring** - Checkbox (default: checked)
10. **Student IDs** - Multi-select checkboxes with search

**Student Selection Interface:**
- Search bar for filtering students by email
- "Select All" button (only selects visible/filtered students)
- "Deselect All" button (clears all selections)
- Selected count display: "X student(s) selected"
- Scrollable list with max-height: 24rem (96 in Tailwind)
- "No students match your search" message when empty
- Pre-selected students for edit form using `@enrolled_student_ids`

**Vanilla JavaScript Features (200+ lines):**

1. **Duration Calculator:**
```javascript
function updateDuration() {
  const start = new Date(`2000-01-01T${startTimeInput.value}`);
  const end = new Date(`2000-01-01T${endTimeInput.value}`);
  const diffMinutes = (end - start) / 1000 / 60;
  const hours = Math.floor(diffMinutes / 60);
  const minutes = diffMinutes % 60;
  // Displays: "Duration: 1 hour 30 minutes"
}
```

2. **Time Validation:**
```javascript
function validateTimes() {
  const start = new Date(`2000-01-01T${startTimeInput.value}`);
  const end = new Date(`2000-01-01T${endTimeInput.value}`);
  if (end <= start) {
    durationDisplay.innerHTML = '<span class="text-red-600 font-medium">End time must be after start time</span>';
    durationDisplay.classList.remove('hidden');
    return false;
  }
  return true;
}
```

3. **Student Search:**
```javascript
studentSearch.addEventListener('input', function() {
  const searchTerm = this.value.toLowerCase();
  studentItems.forEach(item => {
    const email = item.dataset.email;
    const matches = email.includes(searchTerm);
    item.classList.toggle('hidden', !matches);
  });
  updateNoResultsMessage();
});
```

4. **Select All/Deselect All:**
```javascript
// Only selects visible (filtered) students
selectAllBtn.addEventListener('click', function() {
  studentItems.forEach(item => {
    if (!item.classList.contains('hidden')) {
      item.querySelector('.student-checkbox').checked = true;
    }
  });
  updateSelectedCount();
});
```

5. **Selected Count Updates:**
```javascript
function updateSelectedCount() {
  const count = document.querySelectorAll('.student-checkbox:checked').length;
  selectedCount.textContent = count;
}
// Attached to all checkbox change events
```

**Error Handling:**
- Red alert box for validation errors
- Yellow warning box for time conflicts
- Error messages display above form
- Duration validation message in red

**Responsive Design:**
- 2-column grid on desktop (grid-cols-2)
- 1-column on mobile
- Full-width fields for description and student selection
- Scrollable student list prevents page overflow

#### 3. Schedule New View (`app/views/schedules/new.html.erb`)

**Page Structure:**
- Back button to schedules index
- Page title: "Create New Schedule"
- Subtitle: "Set up a new class schedule and enroll students"
- White card container with padding
- Renders `_form` partial with `@schedule` object

**Layout:**
- Min-height screen with gray background (bg-gray-50)
- Centered container with max-width 4xl
- Consistent spacing and typography
- Tailwind utility classes for styling

#### 4. Schedule Edit View (`app/views/schedules/edit.html.erb`)

**Page Structure:**
- Back button to schedule show page
- Page title: "Edit Schedule"
- Subtitle: "Update class schedule and manage enrolled students"
- White card container with padding
- Renders `_form` partial with `@schedule` object

**Pre-Population:**
- Form fields pre-filled with schedule data
- Students pre-selected using `@enrolled_student_ids`
- Controller sets `@enrolled_student_ids` in edit action

#### 5. Schedule Show View (`app/views/schedules/show.html.erb`)

**Comprehensive Schedule Display**

**Layout:**
- 3-column grid on desktop (2/3 details, 1/3 students)
- Single column on mobile
- Back button to schedules index
- Edit/Delete buttons (teacher only)

**Schedule Details Card:**

1. **Day & Time Section:**
   - Blue calendar icon
   - Day name (e.g., "Monday")
   - Time range (e.g., "09:00 AM - 10:30 AM")
   - Duration in hours (e.g., "1.5 hours")

2. **Room Section:**
   - Green building icon
   - Room number/name

3. **Instructor Section:**
   - Purple user icon
   - Instructor full name
   - Falls back to schedule creator if no instructor

4. **Recurring Status:**
   - Yellow refresh icon
   - "Weekly" or "One-time"

5. **Description Section:**
   - Gray document icon
   - Full description text (whitespace-pre-wrap)
   - Only shows if description present

**Enrolled Students Card:**
- Student count badge (blue)
- List of enrolled students with:
  - Avatar circle with first initial
  - Full name
  - Email address
- Empty state with icon and message
- Scrollable if many students

**Authorization:**
- Edit/Delete buttons only visible to:
  - Schedule creator (user_id)
  - Schedule instructor (instructor_id)
- Delete confirmation dialog
- Role-based access control

**Visual Design:**
- Color-coded sections with icons
- Consistent spacing and borders
- Hover effects on interactive elements
- Responsive grid layout
- Card-based design system

#### 6. Route Configuration (`config/routes.rb`)

**Added Routes:**
```ruby
resources :schedules do
  collection do
    post :check_conflicts_ajax
  end
end
```

**Available Routes:**
- GET `/schedules` - Index (role-based)
- POST `/schedules` - Create
- GET `/schedules/new` - New form
- GET `/schedules/:id` - Show details
- GET `/schedules/:id/edit` - Edit form
- PATCH `/schedules/:id` - Update
- DELETE `/schedules/:id` - Destroy
- POST `/schedules/check_conflicts_ajax` - AJAX conflict check

### Testing Checklist:

**Create Schedule:**
- ✅ Form displays all fields correctly
- ✅ Duration calculator works in real-time
- ✅ Time validation prevents invalid ranges
- ✅ Student search filters correctly
- ✅ Select all/deselect all functions
- ✅ Selected count updates dynamically
- ✅ Color picker has default value
- ✅ Recurring checkbox defaults to checked
- ✅ Conflict detection runs on submit
- ✅ Error messages display properly

**Edit Schedule:**
- ✅ Form pre-fills with existing data
- ✅ Enrolled students pre-selected
- ✅ Updates sync student enrollments
- ✅ Removes unenrolled students
- ✅ Adds newly selected students
- ✅ Validates time conflicts on update

**Show Schedule:**
- ✅ Displays all schedule details
- ✅ Shows enrolled students list
- ✅ Edit/Delete buttons for authorized users
- ✅ Empty state when no students
- ✅ Color indicator displays
- ✅ Formatted time range shows

**Authorization:**
- ✅ Only teachers can create schedules
- ✅ Only creators/instructors can edit
- ✅ Only creators/instructors can delete
- ✅ Students can only view enrolled schedules
- ✅ Proper redirects for unauthorized access

### Technical Highlights:

1. **Vanilla JavaScript Only**: No frameworks, pure DOM manipulation
2. **Real-Time Validation**: Duration and time range checks
3. **Smart Search**: Filters students without page reload
4. **Bulk Operations**: Select/deselect all visible students
5. **Conflict Detection**: Server-side validation with AJAX endpoint
6. **Role-Based Access**: Different views for teachers and students
7. **Form Reusability**: Single partial for new and edit
8. **Error Preservation**: User input retained on validation failure
9. **Responsive Design**: Mobile-first with Tailwind CSS
10. **Accessibility**: Proper labels, ARIA attributes, keyboard navigation
11. **Visual Feedback**: Icons, colors, hover states
12. **Data Integrity**: Validates before saving, prevents conflicts
13. **Clean Code**: Separated concerns, DRY principles
14. **Performance**: Efficient queries, minimal database hits
15. **User Experience**: Intuitive interface, clear feedback

### Code Statistics:
- **SchedulesController**: 196 lines (from 30)
- **_form.html.erb**: 346 lines (400+ with formatting)
- **show.html.erb**: 200+ lines
- **Vanilla JavaScript**: 200+ lines across form
- **Total New/Modified**: 5 files

### Next Steps:
Ready to proceed to **Todo #12: Teacher - View/Edit Schedule**

This will involve:
- Enhanced index view with calendar display
- Weekly grid layout showing all schedules
- Day/course/instructor filters
- Color-coded schedule blocks
- Click to view/edit functionality
- Conflict visual indicators
- Statistics cards (total schedules, students, conflicts)
- Use Vanilla JS for:
  - Calendar rendering
  - Interactive filtering
  - Schedule block interactions
  - Modal popups for quick edits

