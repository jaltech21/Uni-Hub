#!/usr/bin/env ruby
# Smoke test to verify basic functionality

require_relative '../config/environment'

puts "🧪 Running Uni-Hub Smoke Tests...\n\n"

def test(description)
  print "Testing: #{description}... "
  begin
    yield
    puts "✅ PASS"
    true
  rescue => e
    puts "❌ FAIL: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    false
  end
end

passed = 0
failed = 0

# Test 1: Database connection
if test("Database connection") do
  ActiveRecord::Base.connection.execute("SELECT 1")
end
  passed += 1
else
  failed += 1
end

# Test 2: User model
if test("User model creation") do
  user = User.new(email: "test@example.com", password: "password123", first_name: "Test", last_name: "User", role: "student")
  raise "User validation failed: #{user.errors.full_messages}" unless user.valid?
end
  passed += 1
else
  failed += 1
end

# Test 3: Assignment model
if test("Assignment model creation") do
  user = User.first || User.create!(email: "teacher@test.com", password: "password123", first_name: "Test", last_name: "Teacher", role: "teacher")
  assignment = Assignment.new(title: "Test", description: "Test assignment", due_date: 1.week.from_now, points: 100, user: user)
  raise "Assignment validation failed: #{assignment.errors.full_messages}" unless assignment.valid?
end
  passed += 1
else
  failed += 1
end

# Test 4: Schedule model
if test("Schedule model creation") do
  user = User.where(role: 'teacher').first || User.create!(email: "teacher2@test.com", password: "password123", first_name: "Test", last_name: "Teacher", role: "teacher")
  schedule = Schedule.new(
    title: "Test Class",
    course: "Computer Science",
    day_of_week: 1,
    start_time: "09:00",
    end_time: "10:30",
    room: "Room 101",
    recurring: true,
    user: user,
    instructor: user
  )
  raise "Schedule validation failed: #{schedule.errors.full_messages}" unless schedule.valid?
end
  passed += 1
else
  failed += 1
end

# Test 5: ScheduleParticipant association
if test("ScheduleParticipant creation") do
  teacher = User.where(role: 'teacher').first
  student = User.where(role: 'student').first || User.create!(email: "student@test.com", password: "password123", first_name: "Test", last_name: "Student", role: "student")
  
  schedule = Schedule.create!(
    title: "Test Class 2",
    course: "Mathematics",
    day_of_week: 2,
    start_time: "11:00",
    end_time: "12:00",
    room: "Room 202",
    recurring: true,
    user: teacher,
    instructor: teacher
  )
  
  participant = ScheduleParticipant.new(schedule: schedule, user: student, role: 'student')
  raise "ScheduleParticipant validation failed: #{participant.errors.full_messages}" unless participant.valid?
  
  # Clean up
  schedule.destroy
end
  passed += 1
else
  failed += 1
end

# Test 6: Mailer configuration
if test("ScheduleMailer configuration") do
  raise "ScheduleMailer not defined" unless defined?(ScheduleMailer)
  raise "ScheduleMailer doesn't respond to class_reminder" unless ScheduleMailer.respond_to?(:class_reminder)
end
  passed += 1
else
  failed += 1
end

# Test 7: Background job
if test("ScheduleReminderJob configuration") do
  raise "ScheduleReminderJob not defined" unless defined?(ScheduleReminderJob)
end
  passed += 1
else
  failed += 1
end

# Test 8: Routes
if test("Routes configuration") do
  raise "schedules_path not defined" unless Rails.application.routes.url_helpers.respond_to?(:schedules_path)
  raise "assignments_path not defined" unless Rails.application.routes.url_helpers.respond_to?(:assignments_path)
  raise "dashboard_path not defined" unless Rails.application.routes.url_helpers.respond_to?(:authenticated_root_path)
end
  passed += 1
else
  failed += 1
end

puts "\n" + "="*50
puts "Results: #{passed} passed, #{failed} failed"
puts "="*50

exit(failed > 0 ? 1 : 0)
