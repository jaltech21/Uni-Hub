# Testing Guide - Assignment Creation Form

## Prerequisites
1. Ensure Rails server is running: `bin/dev`
2. Ensure you're logged in as a **teacher** account
3. Database migrations are up to date: `bin/rails db:migrate`

---

## Test #1: Access the Form

### Steps:
1. Navigate to `http://localhost:3000/assignments/new`
2. Or from dashboard, click "Assignments" → "New Assignment"

### Expected Results:
✅ Form loads without errors  
✅ Page shows "Create New Assignment" header  
✅ All 11 form fields are visible and properly styled  
✅ Tailwind CSS styling is applied (blue buttons, proper spacing)  
✅ File upload drop zone displays with upload icon  

### Potential Issues:
- ❌ **401/403 Error**: Not logged in or not a teacher
  - **Fix**: Log in as teacher account
- ❌ **Routing Error**: Routes not configured
  - **Fix**: Already configured in `config/routes.rb`
- ❌ **Template Missing Error**: View file not found
  - **Fix**: Check `app/views/assignments/new.html.erb` and `_form.html.erb` exist

---

## Test #2: Form Validation - Empty Submission

### Steps:
1. Navigate to `/assignments/new`
2. Leave all fields empty or with defaults
3. Click "Create Assignment" button

### Expected Results:
✅ JavaScript alert appears: "Please enter a title (at least 3 characters)."  
✅ Form does NOT submit  
✅ Button stays enabled after alert dismissal  

### Test Variations:
- Enter 1-2 character title → Should show alert
- Enter 3+ character title but no description → "Please provide an assignment description."
- Fill title + description but clear due date → "Please select a due date and time."
- Fill all but set points to negative → "Please enter valid points (0 or greater)."

---

## Test #3: File Upload - Drag & Drop

### Steps:
1. Navigate to `/assignments/new`
2. Drag a valid file (PDF, DOC, etc.) over the upload zone
3. Drop the file

### Expected Results:
✅ Drop zone highlights with blue border and background during drag  
✅ Blue highlight disappears after drop  
✅ File appears in preview section below with:
  - Appropriate icon (📄 for PDF, 📝 for DOC, etc.)
  - File name displayed
  - File size displayed (e.g., "2.5 MB")
  - Red X button to remove file  

### Test Variations:
- **Large File (>10MB)**: Alert "File is too large. Maximum size is 10MB."
- **Invalid Type (.exe, .bat)**: Alert "File has an unsupported format."
- **Same File Twice**: Alert "File has already been added."
- **Multiple Files**: Drag multiple files at once → All valid files appear in preview

---

## Test #4: File Upload - Click to Select

### Steps:
1. Navigate to `/assignments/new`
2. Click on the "Click to upload or drag and drop" text
3. Select file(s) from file picker dialog

### Expected Results:
✅ File picker opens showing supported formats  
✅ Selected files appear in preview section  
✅ Multiple file selection works (Ctrl+Click or Cmd+Click)  

---

## Test #5: File Management - Remove Files

### Steps:
1. Upload 2-3 files using any method
2. Click the red X button on one file

### Expected Results:
✅ File immediately disappears from preview  
✅ Other files remain visible  
✅ File is removed from form data (won't be submitted)  
✅ Can re-add the same file after removal  

---

## Test #6: Form Submission - Valid Data

### Steps:
1. Fill in all required fields:
   - **Title**: "Test Assignment for CS101"
   - **Course Name**: "Computer Science 101"
   - **Category**: Select "Project"
   - **Points**: 150
   - **Due Date**: Select tomorrow at 11:59 PM
   - **Description**: "This is a comprehensive test of the assignment system..."
   - **Grading Criteria**: "Code quality: 50pts, Documentation: 50pts, Testing: 50pts"
   - **Files**: Upload 1-2 PDF files
   - **Allow Resubmission**: Check the box
2. Click "Create Assignment"

### Expected Results:
✅ Submit button changes to "Creating..." and becomes disabled  
✅ Form submits successfully  
✅ Redirects to assignment show page  
✅ Flash message: "Assignment was successfully created."  
✅ All fields display correct values on show page  
✅ Uploaded files are accessible/downloadable  
✅ Database record created with all attributes  

---

## Test #7: Category Dropdown

### Steps:
1. Navigate to `/assignments/new`
2. Click the Category dropdown

### Expected Results:
✅ Dropdown shows 4 options:
  - Homework (default selected)
  - Project
  - Quiz
  - Exam
✅ Can change selection  
✅ Selected value persists if form has errors  

---

## Test #8: Date Picker

### Steps:
1. Navigate to `/assignments/new`
2. Click on the Due Date field

### Expected Results:
✅ Browser's native datetime picker opens  
✅ Default value is 1 week from now  
✅ Can select both date and time  
✅ Format displays as YYYY-MM-DDTHH:MM (local time)  

---

## Test #9: Form Validation - Server-Side

### Steps:
1. Open browser dev tools (F12) → Console tab
2. In console, bypass JavaScript validation:
   ```javascript
   document.getElementById('assignment-form').onsubmit = null;
   ```
3. Submit form with invalid data (empty title, etc.)

### Expected Results:
✅ Form submits to server  
✅ Server returns with status 422 (Unprocessable Entity)  
✅ Red error box appears at top of form  
✅ Lists all validation errors from Rails model  
✅ Form fields retain entered values  
✅ Can correct errors and resubmit  

---

## Test #10: Edit Form (Bonus)

### Steps:
1. Create an assignment successfully (Test #6)
2. Navigate to `/assignments/:id/edit` (replace :id with actual ID)
3. Modify some fields
4. Click "Update Assignment"

### Expected Results:
✅ Form shows "Edit Assignment" header  
✅ All current values pre-filled in form  
✅ Submit button says "Update Assignment"  
✅ Cancel button goes to show page (not index)  
✅ Update succeeds and redirects to show page  
✅ Flash message: "Assignment was successfully updated."  

---

## Test #11: Responsive Design

### Steps:
1. Open form on desktop (1920x1080)
2. Open dev tools and switch to mobile view (375x667 iPhone)
3. Test form interactions on mobile

### Expected Results:
✅ Form is readable and usable on mobile  
✅ Fields stack vertically on small screens  
✅ Category/Points row becomes single column on mobile  
✅ File upload zone remains functional  
✅ Buttons are easily tappable (proper size)  
✅ No horizontal scrolling required  

---

## Test #12: Browser Compatibility

### Browsers to Test:
- ✅ Chrome/Chromium (Latest)
- ✅ Firefox (Latest)
- ✅ Safari (Latest - macOS/iOS)
- ✅ Edge (Latest)

### Features to Verify:
- File drag & drop works
- Date picker displays correctly
- Tailwind CSS renders properly
- JavaScript runs without errors
- Form submits successfully

---

## Test #13: Performance

### Steps:
1. Upload 10 files (each ~5MB)
2. Fill in all fields with lengthy text
3. Submit form

### Expected Results:
✅ File preview renders quickly (<1s per file)  
✅ Form submission completes within reasonable time  
✅ No browser freezing or lag  
✅ Large file uploads work via Active Storage direct upload  

---

## Database Verification Commands

After successful form submission, verify in Rails console:

```ruby
# Start console
bin/rails console

# Get the last assignment
assignment = Assignment.last

# Verify attributes
assignment.title
assignment.course_name
assignment.category
assignment.points
assignment.due_date
assignment.description
assignment.grading_criteria
assignment.allow_resubmission
assignment.user_id # Should be the teacher's ID

# Verify files are attached
assignment.files.attached? # Should be true if files were uploaded
assignment.files.count # Should match number uploaded
assignment.files.each { |file| puts "#{file.filename} - #{file.byte_size} bytes" }

# Check associations
assignment.user # Should return the teacher User object
assignment.submissions.count # Should be 0 for new assignment
```

---

## Common Issues & Solutions

### Issue: "No route matches [GET] /assignments/new"
**Solution**: Check `config/routes.rb` has `resources :assignments`

### Issue: Template/View not found
**Solution**: Verify files exist:
- `app/views/assignments/new.html.erb`
- `app/views/assignments/_form.html.erb`

### Issue: JavaScript not working
**Solution**: 
1. Check browser console for errors
2. Verify `<script>` tag is inside the form partial
3. Ensure form IDs match JavaScript selectors

### Issue: File upload not working
**Solution**:
1. Verify Active Storage is configured: `bin/rails active_storage:install`
2. Check `config/storage.yml` has correct settings
3. Ensure `direct_upload: true` in file field

### Issue: Styling broken (no colors/spacing)
**Solution**:
1. Check Tailwind CSS compiled: `ls app/assets/builds/application.css`
2. Restart bin/dev to rebuild CSS
3. Verify `stylesheet_link_tag "application"` in layout

### Issue: Form submits but data not saved
**Solution**:
1. Check server logs for errors
2. Verify `assignment_params` permits all fields
3. Check model validations aren't failing
4. Ensure `current_user.assignments.build` is used

---

## Success Criteria

All tests pass when:
- ✅ Form loads without errors for teacher users
- ✅ Client-side validation prevents invalid submissions
- ✅ File upload works (drag-drop and click)
- ✅ File validation catches size/type/duplicate issues
- ✅ Server-side validation catches bypassed client validation
- ✅ Form submits successfully with valid data
- ✅ Database records created with all correct attributes
- ✅ Files are stored via Active Storage
- ✅ Edit form works and updates records
- ✅ Form is responsive and mobile-friendly
- ✅ Works across all major browsers
- ✅ No console errors in browser dev tools
- ✅ No errors in Rails server logs

---

## Next Steps After Testing

Once all tests pass:
1. ✅ Mark Todo #2 as fully tested and verified
2. 🚀 Proceed to **Todo #3: Teacher Assignment Dashboard**
3. 📝 Document any issues found and fixes applied
4. 🎯 Consider additional edge cases or improvements

---

## Quick Test Checklist

Use this for rapid testing:

- [ ] Form loads for teacher
- [ ] All fields visible and styled
- [ ] Client validation alerts work
- [ ] Drag & drop file upload works
- [ ] File preview displays correctly
- [ ] Can remove files
- [ ] Valid submission succeeds
- [ ] Data saved to database correctly
- [ ] Files stored via Active Storage
- [ ] Edit form pre-fills values
- [ ] Update works correctly
- [ ] Mobile responsive
- [ ] No console errors
- [ ] No server errors

**Status**: Ready for testing! 🧪
