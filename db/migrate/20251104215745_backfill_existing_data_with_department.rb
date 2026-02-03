class BackfillExistingDataWithDepartment < ActiveRecord::Migration[8.0]
  def up
    # Create default "General Studies" department if it doesn't exist
    general_dept = Department.find_or_create_by!(code: 'GENERAL') do |dept|
      dept.name = 'General Studies'
      dept.description = 'Default department for existing data'
      dept.active = true
    end
    
    puts "✅ Default department created: #{general_dept.name} (ID: #{general_dept.id})"
    
    # Backfill users without department
    users_updated = User.where(department_id: nil).update_all(department_id: general_dept.id)
    puts "✅ Updated #{users_updated} users with General Studies department"
    
    # Backfill users without role (set to 'student' by default)
    users_role_updated = User.where(role: nil).update_all(role: 'student')
    puts "✅ Updated #{users_role_updated} users with default 'student' role"
    
    # Update 'teacher' role to 'tutor' for consistency with new system
    teacher_to_tutor = User.where(role: 'teacher').update_all(role: 'tutor')
    puts "✅ Updated #{teacher_to_tutor} teachers to tutors"
    
    # Backfill assignments without department
    assignments_updated = Assignment.where(department_id: nil).update_all(department_id: general_dept.id)
    puts "✅ Updated #{assignments_updated} assignments with General Studies department"
    
    # Backfill notes without department
    notes_updated = Note.where(department_id: nil).update_all(department_id: general_dept.id)
    puts "✅ Updated #{notes_updated} notes with General Studies department"
    
    # Backfill quizzes without department
    quizzes_updated = Quiz.where(department_id: nil).update_all(department_id: general_dept.id)
    puts "✅ Updated #{quizzes_updated} quizzes with General Studies department"
    
    # Backfill schedules without department
    schedules_updated = Schedule.where(department_id: nil).update_all(department_id: general_dept.id)
    puts "✅ Updated #{schedules_updated} schedules with General Studies department"
    
    puts "\n📊 Backfill Summary:"
    puts "   - Users: #{users_updated}"
    puts "   - Assignments: #{assignments_updated}"
    puts "   - Notes: #{notes_updated}"
    puts "   - Quizzes: #{quizzes_updated}"
    puts "   - Schedules: #{schedules_updated}"
    puts "   - Total items: #{users_updated + assignments_updated + notes_updated + quizzes_updated + schedules_updated}"
  end
  
  def down
    # Find the General Studies department
    general_dept = Department.find_by(code: 'GENERAL')
    return unless general_dept
    
    # Revert all associations to nil
    User.where(department_id: general_dept.id).update_all(department_id: nil)
    Assignment.where(department_id: general_dept.id).update_all(department_id: nil)
    Note.where(department_id: general_dept.id).update_all(department_id: nil)
    Quiz.where(department_id: general_dept.id).update_all(department_id: nil)
    Schedule.where(department_id: general_dept.id).update_all(department_id: nil)
    
    # Optionally delete the General Studies department
    # general_dept.destroy
    
    puts "✅ Reverted backfill - all items set back to nil department"
  end
end
