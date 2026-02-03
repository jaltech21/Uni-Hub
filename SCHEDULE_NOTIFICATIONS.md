# Schedule Notification System

## Overview
The schedule notification system automatically sends email notifications to students for various schedule-related events using Action Mailer and Solid Queue (Rails 8 default background job processor).

## Features

### 1. **Class Reminders** ⏰
- **When**: Automatically sent 30 minutes before each class
- **Who**: All students enrolled in the class
- **How**: Recurring job runs every 5-10 minutes to check for upcoming classes
- **Contains**: 
  - Class title and course
  - Time and location (room)
  - Instructor name
  - Link to view schedule details

### 2. **Schedule Update Notifications** 📅
- **When**: Sent when a teacher modifies a schedule
- **Who**: All enrolled students
- **Triggers**:
  - Day of week change
  - Time change (start/end)
  - Room change
  - Title or course change
- **Contains**:
  - What changed (before → after)
  - Current complete schedule details
  - Link to view updated schedule

### 3. **Schedule Cancellation Notifications** ❌
- **When**: Sent when a teacher deletes a schedule
- **Who**: All students who were enrolled
- **Contains**:
  - Class details (title, course, day, time)
  - Notice that class has been removed from their schedule
  - Link to view remaining schedules

### 4. **Enrollment Confirmation** ✅
- **When**: Sent when a student is enrolled in a class
- **Triggers**:
  - Teacher creates new schedule with students
  - Teacher adds student to existing schedule
- **Contains**:
  - Complete class information
  - Welcome message
  - Link to view class details

### 5. **Unenrollment Notification** 📤
- **When**: Sent when a student is removed from a class
- **Who**: The removed student
- **Contains**:
  - Class details
  - Notice of removal
  - Link to view remaining schedules

## Technical Implementation

### Components

1. **ScheduleMailer** (`app/mailers/schedule_mailer.rb`)
   - Defines all email types
   - Sets default sender
   - Formats email content

2. **Email Templates** (`app/views/schedule_mailer/`)
   - HTML versions with styled layouts
   - Plain text versions for compatibility
   - Responsive design with icons

3. **Background Jobs**
   - **ScheduleReminderJob**: Sends individual class reminders
   - Uses Solid Queue for reliable processing
   - Automatically retries on failure

4. **Rake Task** (`lib/tasks/schedule_reminders.rake`)
   - `rails schedules:send_reminders`
   - Checks for classes starting in 25-35 minutes
   - Queues reminder jobs for enrolled students
   - Runs every 5-10 minutes via Solid Queue recurring jobs

5. **Controller Integration** (`app/controllers/schedules_controller.rb`)
   - `create`: Sends enrollment confirmations
   - `update`: Detects changes and sends update notifications
   - `update`: Handles enrollment/unenrollment notifications
   - `destroy`: Sends cancellation notifications
   - All use `.deliver_later` for background processing

### Configuration

**Development** (`config/environments/development.rb`):
```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

**Recurring Jobs** (`config/recurring.yml`):
```yaml
development:
  send_class_reminders:
    command: "Rake::Task['schedules:send_reminders'].invoke"
    schedule: every 10 minutes

production:
  send_class_reminders:
    command: "Rake::Task['schedules:send_reminders'].invoke"
    schedule: every 5 minutes
```

## Usage

### Automatic Notifications
All notifications are sent automatically:
- **Create schedule**: Enrollment confirmations sent
- **Update schedule**: Update notifications sent if significant changes detected
- **Delete schedule**: Cancellation notifications sent
- **Modify enrollments**: Enrollment/unenrollment notifications sent
- **Upcoming class**: Reminders sent 30 minutes before

### Manual Testing

**Send test reminder**:
```ruby
schedule = Schedule.first
student = User.where(role: 'student').first
ScheduleMailer.class_reminder(schedule, student).deliver_now
```

**Send test update notification**:
```ruby
changes = { room: ['Room 101', 'Room 202'], time: ['10:00 AM', '11:00 AM'] }
ScheduleMailer.schedule_updated(schedule, student, changes).deliver_now
```

**Run reminder task manually**:
```bash
rails schedules:send_reminders
```

### Development Preview
In development mode, emails open in your browser using `letter_opener` instead of being sent. This allows you to preview emails without configuring SMTP.

## Email Design
All emails feature:
- **Professional header** with gradient background
- **Color-coded sections** based on notification type:
  - Blue: Reminders
  - Yellow: Updates  
  - Red: Cancellations
  - Green: Confirmations
  - Gray: Unenrollment
- **SVG icons** for visual appeal
- **Responsive layout** works on mobile/desktop
- **Clear call-to-action buttons**
- **Plain text fallback** for all emails

## Production Setup

For production deployment, configure SMTP in `config/environments/production.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  domain: ENV['SMTP_DOMAIN'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { 
  host: ENV['APP_HOST'], 
  protocol: 'https' 
}
```

Set environment variables:
- `SMTP_ADDRESS`: Your SMTP server
- `SMTP_PORT`: Usually 587
- `SMTP_DOMAIN`: Your domain
- `SMTP_USERNAME`: SMTP username
- `SMTP_PASSWORD`: SMTP password
- `APP_HOST`: Your production domain

## Background Job Processing

Solid Queue (Rails 8 default) handles background jobs:

**Start worker**:
```bash
rails solid_queue:start
```

**In production** (with systemd or Docker), ensure Solid Queue runs as a separate process.

## Monitoring

**Check queued jobs**:
```ruby
SolidQueue::Job.count
SolidQueue::Job.pending.count
SolidQueue::Job.failed.count
```

**Check recurring tasks**:
```ruby
SolidQueue::RecurringTask.all
```

**View job history**:
```ruby
SolidQueue::Job.finished.last(10)
```

## Troubleshooting

**Emails not sending in development?**
- Check that letter_opener is installed: `bundle show letter_opener`
- Ensure `config.action_mailer.perform_deliveries = true`
- Check browser opens automatically after email sent

**Reminders not sent?**
- Verify Solid Queue is running: `rails solid_queue:start`
- Check recurring task exists: `SolidQueue::RecurringTask.find_by(key: 'send_class_reminders')`
- Manually run: `rails schedules:send_reminders`
- Check schedule has `recurring: true` and enrolled students

**Job failures?**
- Check failed jobs: `SolidQueue::Job.failed`
- View error details: `SolidQueue::Job.failed.last.error`
- Retry failed job: `job.retry`

## Future Enhancements
- Digest emails (daily schedule summary)
- SMS notifications via Twilio
- Push notifications via web push
- Notification preferences per user
- Attendance reminders after missed class
- Assignment deadline reminders integrated with schedule
