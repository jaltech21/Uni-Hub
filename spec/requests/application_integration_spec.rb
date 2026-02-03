# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application Integration', type: :request do
  let(:teacher) { User.create!(email: 'teacher@test.com', password: 'password123', first_name: 'John', last_name: 'Teacher', role: 'teacher', confirmed_at: Time.current) }
  let(:student) { User.create!(email: 'student@test.com', password: 'password123', first_name: 'Jane', last_name: 'Student', role: 'student', confirmed_at: Time.current) }

  before do
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later)
  end

  describe 'Assignment Workflow' do
    it 'allows teacher to create assignment and student to submit' do
      sign_in teacher
      
      # Teacher creates assignment
      post assignments_path, params: {
        assignment: {
          title: 'Test Assignment',
          description: 'Complete this test',
          due_date: 1.week.from_now,
          total_marks: 100
        }
      }
      expect(response).to redirect_to(assignment_path(Assignment.last))
      assignment = Assignment.last
      expect(assignment.title).to eq('Test Assignment')
      expect(assignment.user_id).to eq(teacher.id)
      
      sign_out teacher
      sign_in student
      
      # Student views assignment
      get assignment_path(assignment)
      expect(response).to have_http_status(:success)
      
      # Student submits assignment
      post assignment_submissions_path(assignment), params: {
        submission: {
          content: 'My submission content',
          submitted: true
        }
      }
      expect(response).to redirect_to(assignment_submission_path(assignment, Submission.last))
      submission = Submission.last
      expect(submission.student_id).to eq(student.id)
      expect(submission.content).to eq('My submission content')
      
      sign_out student
      sign_in teacher
      
      # Teacher grades submission
      patch assignment_submission_path(assignment, submission), params: {
        submission: {
          grade: 85,
          feedback: 'Good work!'
        }
      }
      expect(response).to redirect_to(assignment_path(assignment))
      submission.reload
      expect(submission.grade).to eq(85)
      expect(submission.feedback).to eq('Good work!')
    end
  end

  describe 'Schedule Workflow' do
    it 'allows teacher to create schedule and enroll students' do
      sign_in teacher
      
      # Teacher creates schedule
      post schedules_path, params: {
        schedule: {
          title: 'Math 101',
          course: 'Mathematics',
          day_of_week: 1,
          start_time: '09:00',
          end_time: '10:30',
          room: 'Room 101',
          recurring: true,
          color: '#3B82F6'
        },
        student_ids: [student.id]
      }
      expect(response).to redirect_to(schedule_path(Schedule.last))
      schedule = Schedule.last
      expect(schedule.title).to eq('Math 101')
      expect(schedule.students).to include(student)
      
      sign_out teacher
      sign_in student
      
      # Student views their schedule
      get schedules_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Math 101')
      
      # Student views schedule details
      get schedule_path(schedule)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Role-Based Access Control' do
    let(:assignment) { Assignment.create!(title: 'Test', description: 'Test', due_date: 1.week.from_now, total_marks: 100, user: teacher) }
    let(:schedule) { Schedule.create!(title: 'Test', course: 'Test', day_of_week: 1, start_time: '09:00', end_time: '10:00', room: 'Test', user: teacher, instructor: teacher) }

    it 'prevents students from creating assignments' do
      sign_in student
      get new_assignment_path
      expect(response).to redirect_to(assignments_path)
      expect(flash[:alert]).to be_present
    end

    it 'prevents students from editing assignments' do
      sign_in student
      get edit_assignment_path(assignment)
      expect(response).to redirect_to(assignments_path)
      expect(flash[:alert]).to be_present
    end

    it 'prevents students from creating schedules' do
      sign_in student
      get new_schedule_path
      expect(response).to redirect_to(schedules_path)
      expect(flash[:alert]).to be_present
    end

    it 'allows teachers to access their assignments' do
      sign_in teacher
      get assignment_path(assignment)
      expect(response).to have_http_status(:success)
    end

    it 'allows teachers to access their schedules' do
      sign_in teacher
      get schedule_path(schedule)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Dashboard' do
    it 'shows teacher dashboard with correct data' do
      Assignment.create!(title: 'Test', description: 'Test', due_date: 1.week.from_now, total_marks: 100, user: teacher)
      Schedule.create!(title: 'Test', course: 'Test', day_of_week: 1, start_time: '09:00', end_time: '10:00', room: 'Test', user: teacher, instructor: teacher)
      
      sign_in teacher
      get authenticated_root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Total Assignments')
      expect(response.body).to include('Active Schedules')
    end

    it 'shows student dashboard with correct data' do
      assignment = Assignment.create!(title: 'Test', description: 'Test', due_date: 1.week.from_now, total_marks: 100, user: teacher)
      schedule = Schedule.create!(title: 'Test', course: 'Test', day_of_week: 1, start_time: '09:00', end_time: '10:00', room: 'Test', user: teacher, instructor: teacher)
      schedule.add_participant(student, role: 'student')
      
      sign_in student
      get authenticated_root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Total Assignments')
      expect(response.body).to include('Enrolled Classes')
    end
  end
end
