require "test_helper"

class Week2Task5Test < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    # Create test users
    @admin = User.create!(
      email: 'admin_task5@test.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      role: 'admin'
    )
    
    @teacher = User.create!(
      email: 'teacher_task5@test.com',
      password: 'password123',
      first_name: 'Emma',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    @student = User.create!(
      email: 'student_task5@test.com',
      password: 'password123',
      first_name: 'Alice',
      last_name: 'Student',
      role: 'student'
    )
    
    @frank = User.create!(
      email: 'frank_task5@test.com',
      password: 'password123',
      first_name: 'Frank',
      last_name: 'Garcia',
      role: 'teacher'
    )
    
    @grace = User.create!(
      email: 'grace_task5@test.com',
      password: 'password123',
      first_name: 'Grace',
      last_name: 'Lee',
      role: 'teacher'
    )
    
    # Create test departments with unique codes
    rand_id = rand(10000..99999)
    @cs_dept = Department.create!(
      name: 'Computer Science Test',
      code: "CS#{rand_id}",
      description: 'Test CS department'
    )
    
    @math_dept = Department.create!(
      name: 'Mathematics Test',
      code: "MA#{rand_id}",
      description: 'Test Math department'
    )
    
    # Ensure admin is signed in for tests
    sign_in @admin
    
    # Create a test member
    @member = @cs_dept.user_departments.create!(
      user: @teacher,
      role: 'teacher',
      status: 'active',
      joined_at: 1.month.ago,
      invited_by: @admin,
      notes: 'Test member'
    )
  end

  # Test 1: Enhanced UserDepartment Model
  test "user_department has new fields and validations" do
    # Create a new teacher for this test
    new_teacher = User.create!(
      email: 'newteacher_task5@test.com',
      password: 'password123',
      first_name: 'New',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    member = UserDepartment.new(
      user: new_teacher,
      department: @math_dept,
      role: 'member',
      status: 'active'
    )
    
    assert member.valid?, "Member should be valid: #{member.errors.full_messages.join(', ')}"
    assert_equal 'member', member.role
    assert_equal 'active', member.status
  end

  test "user_department validates role" do
    member = @cs_dept.user_departments.build(user: @teacher, role: 'invalid')
    assert_not member.valid?
    assert_includes member.errors[:role], "invalid is not a valid role"
  end

  test "user_department validates status" do
    member = @cs_dept.user_departments.build(user: @teacher, role: 'member', status: 'invalid')
    assert_not member.valid?
    assert_includes member.errors[:status], "invalid is not a valid status"
  end

  test "user_department scopes work correctly" do
    active = @cs_dept.user_departments.create!(user: @frank, role: 'member', status: 'active')
    inactive = @cs_dept.user_departments.create!(user: @grace, role: 'member', status: 'inactive')
    
    assert_includes @cs_dept.user_departments.active, active
    assert_not_includes @cs_dept.user_departments.active, inactive
    assert_includes @cs_dept.user_departments.inactive, inactive
  end

  test "user_department activate! method" do
    @member.update!(status: 'inactive', left_at: Time.current)
    @member.activate!
    
    assert @member.active?
    assert_nil @member.left_at
  end

  test "user_department deactivate! method" do
    @member.deactivate!
    
    assert @member.inactive?
    assert_not_nil @member.left_at
  end

  test "user_department duration calculation" do
    @member.update!(joined_at: 30.days.ago, left_at: Time.current)
    assert_equal 30, @member.duration
  end

  # Test 2: DepartmentMemberHistory Model
  test "department_member_history logs addition" do
    assert_difference 'DepartmentMemberHistory.count', 1 do
      DepartmentMemberHistory.log_addition(@teacher, @cs_dept, @admin, { role: 'teacher' })
    end
    
    history = DepartmentMemberHistory.last
    assert_equal 'added', history.action
    assert_equal @teacher, history.user
    assert_equal @cs_dept, history.department
    assert_equal @admin, history.performed_by
  end

  test "department_member_history logs removal" do
    assert_difference 'DepartmentMemberHistory.count', 1 do
      DepartmentMemberHistory.log_removal(@teacher, @cs_dept, @admin, { reason: 'resigned' })
    end
    
    history = DepartmentMemberHistory.last
    assert_equal 'removed', history.action
  end

  test "department_member_history logs role change" do
    assert_difference 'DepartmentMemberHistory.count', 1 do
      DepartmentMemberHistory.log_role_change(@teacher, @cs_dept, @admin, 'member', 'teacher')
    end
    
    history = DepartmentMemberHistory.last
    assert_equal 'role_changed', history.action
    assert_equal 'member', history.details['old_role']
    assert_equal 'teacher', history.details['new_role']
  end

  test "department_member_history description generation" do
    history = DepartmentMemberHistory.create!(
      user: @teacher,
      department: @cs_dept,
      action: 'added',
      performed_by: @admin
    )
    
    assert_equal "#{@teacher.full_name} was added to #{@cs_dept.name}", history.description
  end

  test "department_member_history scopes" do
    h1 = DepartmentMemberHistory.create!(user: @teacher, department: @cs_dept, action: 'added', performed_by: @admin)
    h2 = DepartmentMemberHistory.create!(user: @teacher, department: @cs_dept, action: 'removed', performed_by: @admin)
    
    assert_includes DepartmentMemberHistory.by_action('added'), h1
    assert_includes DepartmentMemberHistory.by_action('removed'), h2
    assert_includes DepartmentMemberHistory.for_user(@teacher), h1
    assert_includes DepartmentMemberHistory.for_department(@cs_dept), h1
  end

  # Test 3: CSV Import Service
  test "csv import service imports valid users" do
    csv_content = "email,role,notes\n#{@frank.email},teacher,Test import\n"
    file = Tempfile.new(['test', '.csv'])
    file.write(csv_content)
    file.rewind
    
    service = DepartmentMemberImportService.new(@cs_dept, file.path, @admin)
    assert service.import
    
    summary = service.summary
    assert_equal 1, summary[:total]
    assert_equal 1, summary[:successful]
    assert_equal 0, summary[:failed]
    
    file.close
    file.unlink
  end

  test "csv import service handles errors" do
    csv_content = "email,role,notes\nnonexistent@test.com,teacher,Test\n"
    file = Tempfile.new(['test', '.csv'])
    file.write(csv_content)
    file.rewind
    
    service = DepartmentMemberImportService.new(@cs_dept, file.path, @admin)
    service.import
    
    summary = service.summary
    assert_equal 1, summary[:failed]
    assert_includes summary[:errors].first[:error], "User not found"
    
    file.close
    file.unlink
  end

  test "csv import service reactivates inactive members" do
    inactive_member = @cs_dept.user_departments.create!(
      user: @grace,
      role: 'member',
      status: 'inactive'
    )
    
    csv_content = "email,role\n#{@grace.email},teacher\n"
    file = Tempfile.new(['test', '.csv'])
    file.write(csv_content)
    file.rewind
    
    service = DepartmentMemberImportService.new(@cs_dept, file.path, @admin)
    service.import
    
    inactive_member.reload
    assert_equal 'active', inactive_member.status
    assert_equal 'teacher', inactive_member.role
    
    file.close
    file.unlink
  end

  # Test 4: Members Controller
  test "should get members index" do
    get department_members_path(@cs_dept)
    assert_response :success
    assert_select 'h1', text: /Members/i
  end

  test "members index shows stats" do
    get department_members_path(@cs_dept)
    assert_response :success
    assert_select '.text-gray-500', text: /Total Members/i
  end

  test "members index supports search" do
    get department_members_path(@cs_dept), params: { search: @teacher.first_name }
    assert_response :success
  end

  test "members index supports role filter" do
    get department_members_path(@cs_dept), params: { role: 'teacher' }
    assert_response :success
  end

  test "should get member show page" do
    get department_member_path(@cs_dept, @member)
    assert_response :success
    assert_select 'h1', text: @teacher.full_name
  end

  test "should get new member form" do
    get new_department_member_path(@cs_dept)
    assert_response :success
    assert_select 'h1', text: /Add New Member/i
  end

  test "should create member" do
    new_teacher = @frank
    
    assert_difference '@cs_dept.user_departments.count', 1 do
      post department_members_path(@cs_dept), params: {
        user_department: {
          user_id: new_teacher.id,
          role: 'teacher',
          status: 'active',
          notes: 'Test creation'
        }
      }
    end
    
    assert_redirected_to department_members_path(@cs_dept)
    follow_redirect!
    assert_select '.alert', text: /added successfully/i
  end

  test "should get edit member form" do
    get edit_department_member_path(@cs_dept, @member)
    assert_response :success
    assert_select 'h1', text: /Edit Member/i
  end

  test "should update member" do
    patch department_member_path(@cs_dept, @member), params: {
      user_department: {
        role: 'admin',
        notes: 'Updated notes'
      }
    }
    
    assert_redirected_to department_member_path(@cs_dept, @member)
    @member.reload
    assert_equal 'admin', @member.role
    assert_equal 'Updated notes', @member.notes
  end

  test "should delete member" do
    assert_difference '@cs_dept.user_departments.count', -1 do
      delete department_member_path(@cs_dept, @member)
    end
    
    assert_redirected_to department_members_path(@cs_dept)
  end

  # Test 5: Bulk Operations
  test "should bulk add members" do
    emails = "#{@frank.email}\n#{@grace.email}"
    
    post bulk_add_department_members_path(@cs_dept), params: {
      emails: emails,
      role: 'member'
    }
    
    assert_redirected_to department_members_path(@cs_dept)
    follow_redirect!
    assert_select '.alert', text: /2 members added/i
  end

  test "bulk add handles invalid emails" do
    emails = "#{@frank.email}\ninvalid@test.com"
    
    post bulk_add_department_members_path(@cs_dept), params: {
      emails: emails,
      role: 'member'
    }
    
    assert_redirected_to department_members_path(@cs_dept)
  end

  test "should bulk remove members" do
    member1 = @cs_dept.user_departments.create!(user: @frank, role: 'member', status: 'active')
    member2 = @cs_dept.user_departments.create!(user: @grace, role: 'member', status: 'active')
    
    assert_difference '@cs_dept.user_departments.count', -2 do
      post bulk_remove_department_members_path(@cs_dept), params: {
        member_ids: [member1.id, member2.id]
      }
    end
    
    assert_redirected_to department_members_path(@cs_dept)
  end

  # Test 6: History Tracking
  test "should get history page" do
    DepartmentMemberHistory.create!(
      user: @teacher,
      department: @cs_dept,
      action: 'added',
      performed_by: @admin
    )
    
    get history_department_members_path(@cs_dept)
    assert_response :success
    assert_select 'h1', text: /Member History/i
  end

  test "creating member logs history" do
    assert_difference 'DepartmentMemberHistory.count', 1 do
      post department_members_path(@cs_dept), params: {
        user_department: {
          user_id: @frank.id,
          role: 'teacher',
          status: 'active'
        }
      }
    end
  end

  test "updating member logs history" do
    old_role = @member.role
    
    assert_difference 'DepartmentMemberHistory.count', 1 do
      patch department_member_path(@cs_dept, @member), params: {
        user_department: { role: 'admin' }
      }
    end
    
    history = DepartmentMemberHistory.last
    assert_equal 'role_changed', history.action
  end

  test "deleting member logs history" do
    assert_difference 'DepartmentMemberHistory.count', 1 do
      delete department_member_path(@cs_dept, @member)
    end
    
    history = DepartmentMemberHistory.last
    assert_equal 'removed', history.action
  end

  # Test 7: CSV Export
  test "should export members to csv" do
    get export_department_members_path(@cs_dept, format: :csv)
    assert_response :success
    assert_equal 'text/csv', response.content_type
    assert_match /email,name,role,status/, response.body
  end

  # Test 8: Authorization
  test "non-admin non-teacher cannot manage members" do
    sign_in @student
    
    get new_department_member_path(@cs_dept)
    assert_redirected_to root_path
    follow_redirect!
    assert_select '.alert', text: /not authorized/i
  end

  test "teacher can manage their department members" do
    sign_in @teacher
    
    get department_members_path(@cs_dept)
    assert_response :success
  end

  test "admin can manage all department members" do
    sign_in @admin
    
    get department_members_path(@cs_dept)
    assert_response :success
  end

  # Test 9: Department Methods
  test "department all_members includes students and teachers" do
    members = @cs_dept.all_members
    assert members.any?
  end

  test "department active_members filters by status" do
    @cs_dept.user_departments.create!(user: @frank, role: 'member', status: 'active')
    @cs_dept.user_departments.create!(user: @grace, role: 'member', status: 'inactive')
    
    active = @cs_dept.active_members
    assert active.all? { |m| m.status == 'active' }
  end

  test "department member_count is accurate" do
    count = @cs_dept.member_count
    assert count > 0
  end
end
