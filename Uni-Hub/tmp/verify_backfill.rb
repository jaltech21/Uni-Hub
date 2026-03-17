#!/usr/bin/env ruby
# Verification script for backfill migration

puts "🔍 Verification Report: Data Backfill"
puts "=" * 60

# Check departments
puts "\n📚 Departments:"
Department.ordered.each do |dept|
  puts "   - #{dept.code}: #{dept.name} (Active: #{dept.active})"
end

# Check users
puts "\n👥 Users Status:"
puts "   Total Users: #{User.count}"
puts "   Users with department: #{User.where.not(department_id: nil).count}"
puts "   Users without department: #{User.where(department_id: nil).count}"
puts "   Users with null role: #{User.where(role: nil).count}"

# Breakdown by role
puts "\n   Users by Role:"
User.group(:role).count.each do |role, count|
  puts "     - #{role}: #{count} users"
end

# Check assignments
puts "\n📝 Assignments Status:"
puts "   Total Assignments: #{Assignment.count}"
puts "   Assignments with department: #{Assignment.where.not(department_id: nil).count}"
puts "   Assignments without department: #{Assignment.where(department_id: nil).count}"

# Check notes
puts "\n📓 Notes Status:"
puts "   Total Notes: #{Note.count}"
puts "   Notes with department: #{Note.where.not(department_id: nil).count}"
puts "   Notes without department: #{Note.where(department_id: nil).count}"

# Check quizzes
puts "\n📋 Quizzes Status:"
puts "   Total Quizzes: #{Quiz.count}"
puts "   Quizzes with department: #{Quiz.where.not(department_id: nil).count}"
puts "   Quizzes without department: #{Quiz.where(department_id: nil).count}"

# Final verification
puts "\n✅ Data Integrity Check:"
null_dept_users = User.where(department_id: nil).count
null_dept_assignments = Assignment.where(department_id: nil).count
null_dept_notes = Note.where(department_id: nil).count
null_dept_quizzes = Quiz.where(department_id: nil).count
null_role_users = User.where(role: nil).count

all_good = (null_dept_users == 0 && null_dept_assignments == 0 && 
            null_dept_notes == 0 && null_dept_quizzes == 0 && null_role_users == 0)

if all_good
  puts "   🎉 PASS: All data has been properly assigned!"
  puts "   ✅ No users without department"
  puts "   ✅ No users without role"
  puts "   ✅ No assignments without department"
  puts "   ✅ No notes without department"
  puts "   ✅ No quizzes without department"
else
  puts "   ⚠️  WARNING: Some data still missing departments or roles"
  puts "   - Users without department: #{null_dept_users}"
  puts "   - Users without role: #{null_role_users}"
  puts "   - Assignments without department: #{null_dept_assignments}"
  puts "   - Notes without department: #{null_dept_notes}"
  puts "   - Quizzes without department: #{null_dept_quizzes}"
end

puts "\n" + "=" * 60
puts "Week 0 Migration Complete! 🎉"
