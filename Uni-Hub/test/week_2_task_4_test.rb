#!/usr/bin/env ruby
# test/week_2_task_4_test.rb

require 'test_helper'

class Week2Task4Test < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  def login_as(user)
    post user_session_path, params: { user: { email: user.email, password: 'password123' } }
  end
  
  setup do
    # Create test users
    @admin = User.create!(
      email: 'admin_task4@test.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      role: 'admin'
    )
    
    @teacher = User.create!(
      email: 'teacher_task4@test.com',
      password: 'password123',
      first_name: 'Teacher',
      last_name: 'User',
      role: 'teacher'
    )
    
    @student = User.create!(
      email: 'student_task4@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'User',
      role: 'student'
    )
    
    # Create test department
    @department = Department.create!(
      name: 'Computer Science',
      code: 'CS',
      description: 'Test department'
    )
    
    # Add members to department
    # For admin and teacher, use user_departments (for multi-department users)
    @department.user_departments.create!(user: @admin)
    @department.user_departments.create!(user: @teacher)
    
    # For student, assign directly via department_id
    @student.update!(department: @department)
    
    @settings = @department.settings
  end

  # ============================================================================
  # Task 4.1: Department Settings Model & Database
  # ============================================================================
  
  test "department has settings" do
    assert_not_nil @department.settings
    assert_instance_of DepartmentSetting, @department.settings
  end
  
  test "department settings have default values" do
    assert_equal '#3B82F6', @settings.primary_color
    assert_equal '#10B981', @settings.secondary_color
    assert_equal 'department', @settings.default_assignment_visibility
    assert_equal 'private', @settings.default_note_visibility
    assert_equal 'department', @settings.default_quiz_visibility
    assert @settings.enable_announcements
    assert @settings.enable_content_sharing
  end
  
  test "settings validates color format" do
    @settings.primary_color = 'invalid'
    assert_not @settings.valid?
    assert_includes @settings.errors[:primary_color], 'must be a valid hex color'
    
    @settings.primary_color = '#FF0000'
    assert @settings.valid?
  end
  
  test "settings validates visibility options" do
    @settings.default_assignment_visibility = 'invalid'
    assert_not @settings.valid?
    assert_includes @settings.errors[:default_assignment_visibility], 'is not included in the list'
    
    @settings.default_assignment_visibility = 'shared'
    assert @settings.valid?
  end
  
  # ============================================================================
  # Task 4.2: Branding Customization
  # ============================================================================
  
  test "can update branding colors" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        primary_color: '#FF5733',
        secondary_color: '#33C3FF'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal '#FF5733', @settings.primary_color
    assert_equal '#33C3FF', @settings.secondary_color
  end
  
  test "can update logo and banner" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        logo_url: 'https://example.com/logo.png',
        banner_url: 'https://example.com/banner.jpg'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal 'https://example.com/logo.png', @settings.logo_url
    assert_equal 'https://example.com/banner.jpg', @settings.banner_url
  end
  
  test "has_branding? returns correct value" do
    assert_not @settings.has_branding?
    
    @settings.update!(logo_url: 'https://example.com/logo.png')
    assert @settings.has_branding?
  end
  
  # ============================================================================
  # Task 4.3: Custom Messages
  # ============================================================================
  
  test "can update welcome and footer messages" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        welcome_message: 'Welcome to our department!',
        footer_message: 'Contact us at cs@university.edu'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal 'Welcome to our department!', @settings.welcome_message
    assert_equal 'Contact us at cs@university.edu', @settings.footer_message
  end
  
  test "has_welcome_message? returns correct value" do
    assert_not @settings.has_welcome_message?
    
    @settings.update!(welcome_message: 'Welcome!')
    assert @settings.has_welcome_message?
  end
  
  # ============================================================================
  # Task 4.4: Default Visibility Settings
  # ============================================================================
  
  test "can update default visibility settings" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        default_assignment_visibility: 'shared',
        default_note_visibility: 'private',
        default_quiz_visibility: 'shared'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal 'shared', @settings.default_assignment_visibility
    assert_equal 'private', @settings.default_note_visibility
    assert_equal 'shared', @settings.default_quiz_visibility
  end
  
  # ============================================================================
  # Task 4.5: Content Templates
  # ============================================================================
  
  test "can manage assignment templates" do
    template_data = {
      'id' => SecureRandom.uuid,
      'name' => 'Essay Template',
      'description' => 'Standard essay format',
      'instructions' => 'Write a 5-paragraph essay...'
    }
    
    @settings.update_template('assignment_templates', template_data)
    @settings.reload
    
    assert_equal 1, @settings.assignment_templates.length
    assert_equal 'Essay Template', @settings.assignment_templates.first['name']
    
    retrieved = @settings.get_template('assignment_templates', template_data['id'])
    assert_equal 'Essay Template', retrieved['name']
    
    @settings.remove_template('assignment_templates', template_data['id'])
    @settings.reload
    assert_empty @settings.assignment_templates
  end
  
  test "can manage quiz templates" do
    template_data = {
      'id' => SecureRandom.uuid,
      'name' => 'Multiple Choice Template',
      'question_count' => 10,
      'time_limit' => 30
    }
    
    @settings.update_template('quiz_templates', template_data)
    @settings.reload
    
    assert_equal 1, @settings.quiz_templates.length
    assert_equal 'Multiple Choice Template', @settings.quiz_templates.first['name']
  end
  
  test "can add template via controller" do
    login_as @admin
    
    post add_template_department_settings_path(@department), params: {
      template_type: 'assignment_templates',
      template_data: {
        name: 'Lab Report Template',
        description: 'Standard lab report format'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal 1, @settings.assignment_templates.length
  end
  
  test "can remove template via controller" do
    template_id = SecureRandom.uuid
    @settings.update_template('assignment_templates', {
      'id' => template_id,
      'name' => 'Test Template'
    })
    @settings.reload
    
    login_as @admin
    
    delete remove_template_department_settings_path(@department), params: {
      template_type: 'assignment_templates',
      template_id: template_id
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_empty @settings.assignment_templates
  end
  
  # ============================================================================
  # Task 4.6: Feature Toggles
  # ============================================================================
  
  test "can toggle features" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        enable_announcements: false,
        enable_content_sharing: false,
        enable_peer_review: true,
        enable_gamification: true
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_not @settings.enable_announcements
    assert_not @settings.enable_content_sharing
    assert @settings.enable_peer_review
    assert @settings.enable_gamification
  end
  
  # ============================================================================
  # Task 4.7: Notification Preferences
  # ============================================================================
  
  test "can update notification preferences" do
    login_as @admin
    
    patch department_settings_path(@department), params: {
      department_setting: {
        notify_new_members: false,
        notify_new_content: true,
        notify_submissions: true
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_not @settings.notify_new_members
    assert @settings.notify_new_content
    assert @settings.notify_submissions
  end
  
  # ============================================================================
  # Task 4.8: Custom Fields
  # ============================================================================
  
  test "can manage custom fields" do
    @settings.set_custom_field('slack_webhook', 'https://hooks.slack.com/...')
    @settings.set_custom_field('contact_email', 'cs@university.edu')
    @settings.save
    @settings.reload
    
    assert_equal 'https://hooks.slack.com/...', @settings.custom_field('slack_webhook')
    assert_equal 'cs@university.edu', @settings.custom_field('contact_email')
    
    @settings.set_custom_field('slack_webhook', nil)
    @settings.save
    @settings.reload
    
    assert_nil @settings.custom_field('slack_webhook')
  end
  
  # ============================================================================
  # Task 4.9: Authorization
  # ============================================================================
  
  test "admin can access settings" do
    post user_session_path, params: { user: { email: @admin.email, password: 'password123' } }
    get department_settings_path(@department)
    assert_response :success
  end
  
  test "teacher can access settings" do
    post user_session_path, params: { user: { email: @teacher.email, password: 'password123' } }
    get department_settings_path(@department)
    assert_response :success
  end
  
  test "student cannot access settings" do
    post user_session_path, params: { user: { email: @student.email, password: 'password123' } }
    get department_settings_path(@department)
    assert_redirected_to root_path
    follow_redirect!
    assert_match /not authorized/i, response.body
  end
  
  test "teacher can update settings" do
    login_as @teacher
    
    patch department_settings_path(@department), params: {
      department_setting: {
        primary_color: '#FF5733'
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    @settings.reload
    assert_equal '#FF5733', @settings.primary_color
  end
  
  test "student cannot update settings" do
    login_as @student
    
    patch department_settings_path(@department), params: {
      department_setting: {
        primary_color: '#FF5733'
      }
    }
    
    assert_redirected_to root_path
    @settings.reload
    assert_not_equal '#FF5733', @settings.primary_color
  end
  
  # ============================================================================
  # Task 4.10: Settings Preview
  # ============================================================================
  
  test "can preview department branding" do
    @settings.update!(
      primary_color: '#FF5733',
      secondary_color: '#33C3FF',
      welcome_message: 'Welcome to our department!',
      footer_message: 'Contact us'
    )
    
    login_as @admin
    get preview_department_settings_path(@department)
    assert_response :success
    assert_select 'h1', text: @department.name
  end
  
  # ============================================================================
  # Task 4.11: Integration Tests
  # ============================================================================
  
  test "settings are created automatically for new department" do
    new_dept = Department.create!(
      name: 'Test Department',
      code: 'TEST',
      description: 'Test'
    )
    
    assert_not_nil new_dept.settings
    assert_equal '#3B82F6', new_dept.settings.primary_color
  end
  
  test "can perform full settings customization workflow" do
    login_as @admin
    
    # Step 1: View current settings
    get department_settings_path(@department)
    assert_response :success
    
    # Step 2: Go to edit page
    get edit_department_settings_path(@department)
    assert_response :success
    
    # Step 3: Update all settings categories
    patch department_settings_path(@department), params: {
      department_setting: {
        # Branding
        primary_color: '#FF5733',
        secondary_color: '#33C3FF',
        logo_url: 'https://example.com/logo.png',
        banner_url: 'https://example.com/banner.jpg',
        
        # Messages
        welcome_message: 'Welcome!',
        footer_message: 'Contact us',
        
        # Visibility
        default_assignment_visibility: 'shared',
        default_note_visibility: 'private',
        default_quiz_visibility: 'shared',
        
        # Features
        enable_announcements: true,
        enable_content_sharing: true,
        enable_peer_review: true,
        enable_gamification: true,
        
        # Notifications
        notify_new_members: true,
        notify_new_content: true,
        notify_submissions: true
      }
    }
    
    assert_redirected_to department_settings_path(@department)
    follow_redirect!
    assert_response :success
    
    # Step 4: Verify all changes
    @settings.reload
    assert_equal '#FF5733', @settings.primary_color
    assert_equal '#33C3FF', @settings.secondary_color
    assert_equal 'shared', @settings.default_assignment_visibility
    assert @settings.enable_peer_review
    assert @settings.notify_new_members
    
    # Step 5: Preview the branding
    get preview_department_settings_path(@department)
    assert_response :success
  end
end

puts "\n" + "="*80
puts "WEEK 2 - TASK 4: DEPARTMENT SETTINGS & CUSTOMIZATION TEST SUITE"
puts "="*80

# Run the tests
require 'minitest/autorun'
