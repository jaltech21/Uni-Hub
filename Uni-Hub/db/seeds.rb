# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting seed process..."

# Clean up existing data in development (optional - comment out if you want to preserve existing data)
if Rails.env.development?
  puts "⚠️  Cleaning existing seed data..."
  # Be careful with these - only uncomment if you want to reset everything
  # UserDepartment.destroy_all
  # AssignmentDepartment.destroy_all
  # User.where(email: [
  #   'admin@unihub.edu', 'student1@unihub.edu', 'student2@unihub.edu',
  #   'tutor1@unihub.edu', 'tutor2@unihub.edu', 'teacher@unihub.edu'
  # ]).destroy_all
  # Department.where(code: ['CS', 'ENG', 'BUS', 'MATH', 'BIO', 'PHYS', 'GEN']).destroy_all
end

# Create ActiveAdmin user
puts "\n👤 Creating ActiveAdmin user..."
AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
  admin.password = 'password'
  admin.password_confirmation = 'password'
  puts "   ✅ Created ActiveAdmin user: admin@example.com"
end

# Create Departments
puts "\n🏢 Creating Departments..."
departments_data = [
  {
    name: 'Computer Science',
    code: 'CS',
    description: 'Department of Computer Science and Software Engineering. Focuses on programming, algorithms, AI, and system design.',
    active: true
  },
  {
    name: 'Engineering',
    code: 'ENG',
    description: 'Department of Engineering. Covers mechanical, electrical, civil, and general engineering principles.',
    active: true
  },
  {
    name: 'Business Administration',
    code: 'BUS',
    description: 'Department of Business and Management. Includes marketing, finance, entrepreneurship, and organizational behavior.',
    active: true
  },
  {
    name: 'Mathematics',
    code: 'MATH',
    description: 'Department of Mathematics. Pure and applied mathematics, statistics, and computational mathematics.',
    active: true
  },
  {
    name: 'Biology',
    code: 'BIO',
    description: 'Department of Biological Sciences. Molecular biology, genetics, ecology, and life sciences.',
    active: true
  },
  {
    name: 'Physics',
    code: 'PHYS',
    description: 'Department of Physics. Classical mechanics, quantum physics, thermodynamics, and astrophysics.',
    active: true
  },
  {
    name: 'General Studies',
    code: 'GEN',
    description: 'General Studies Department. For interdisciplinary courses and general education requirements.',
    active: true
  }
]

departments = {}
departments_data.each do |dept_data|
  dept = Department.find_or_create_by!(code: dept_data[:code]) do |d|
    d.name = dept_data[:name]
    d.description = dept_data[:description]
    d.active = dept_data[:active]
  end
  departments[dept.code] = dept
  puts "   ✅ #{dept.code}: #{dept.name}"
end

# Create Test Users
puts "\n👥 Creating Test Users..."

# Super Admin
admin = User.find_or_create_by!(email: 'osmanjalloh098@gmail.com') do |u|
  u.first_name = 'Osman'
  u.last_name = 'Jalloh'
  u.role = 'admin'
  u.department = departments['GEN']
  u.password = '012198_Oj'
  u.password_confirmation = '012198_Oj'
end
puts "   ✅ Admin: #{admin.email} (#{admin.role})"

# CS Department Students
cs_student1 = User.find_or_create_by!(email: 'alice.smith@unihub.edu') do |u|
  u.first_name = 'Alice'
  u.last_name = 'Smith'
  u.role = 'student'
  u.department = departments['CS']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
puts "   ✅ CS Student: #{cs_student1.email}"

cs_student2 = User.find_or_create_by!(email: 'bob.jones@unihub.edu') do |u|
  u.first_name = 'Bob'
  u.last_name = 'Jones'
  u.role = 'student'
  u.department = departments['CS']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
puts "   ✅ CS Student: #{cs_student2.email}"

# Business Department Student
bus_student = User.find_or_create_by!(email: 'carol.williams@unihub.edu') do |u|
  u.first_name = 'Carol'
  u.last_name = 'Williams'
  u.role = 'student'
  u.department = departments['BUS']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
puts "   ✅ Business Student: #{bus_student.email}"

# Math Department Student
math_student = User.find_or_create_by!(email: 'david.brown@unihub.edu') do |u|
  u.first_name = 'David'
  u.last_name = 'Brown'
  u.role = 'student'
  u.department = departments['MATH']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
puts "   ✅ Math Student: #{math_student.email}"

# CS Tutor (teaches CS and Math)
cs_tutor = User.find_or_create_by!(email: 'emma.tutor@unihub.edu') do |u|
  u.first_name = 'Emma'
  u.last_name = 'Davis'
  u.role = 'tutor'
  u.department = departments['CS']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
# Assign teaching departments
cs_tutor.teaching_departments = [departments['CS'], departments['MATH']]
puts "   ✅ Tutor: #{cs_tutor.email} (teaches CS, MATH)"

# Business Teacher (teaches only Business)
bus_teacher = User.find_or_create_by!(email: 'frank.teacher@unihub.edu') do |u|
  u.first_name = 'Frank'
  u.last_name = 'Garcia'
  u.role = 'teacher'
  u.department = departments['BUS']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
bus_teacher.teaching_departments = [departments['BUS']]
puts "   ✅ Teacher: #{bus_teacher.email} (teaches BUS)"

# Multi-department Teacher (teaches Engineering, Physics, and Math)
multi_teacher = User.find_or_create_by!(email: 'grace.multiprof@unihub.edu') do |u|
  u.first_name = 'Grace'
  u.last_name = 'Martinez'
  u.role = 'teacher'
  u.department = departments['ENG']
  u.password = 'password123'
  u.password_confirmation = 'password123'
end
multi_teacher.teaching_departments = [departments['ENG'], departments['PHYS'], departments['MATH']]
puts "   ✅ Teacher: #{multi_teacher.email} (teaches ENG, PHYS, MATH)"

# Create Sample Content
puts "\n📝 Creating Sample Content..."

# CS Assignment
cs_assignment = Assignment.find_or_create_by!(
  title: 'Data Structures Project',
  user: cs_tutor
) do |a|
  a.description = 'Implement a binary search tree with insert, delete, and search operations. Include unit tests.'
  a.due_date = 2.weeks.from_now
  a.points = 100
  a.category = 'project'
  a.course_name = 'CS 301'
  a.department = departments['CS']
end
puts "   ✅ Assignment: #{cs_assignment.title} (CS)"

# Business Assignment
bus_assignment = Assignment.find_or_create_by!(
  title: 'Marketing Strategy Analysis',
  user: bus_teacher
) do |a|
  a.description = 'Analyze a real-world company marketing campaign and propose improvements.'
  a.due_date = 1.week.from_now
  a.points = 50
  a.category = 'homework'
  a.course_name = 'BUS 201'
  a.department = departments['BUS']
end
puts "   ✅ Assignment: #{bus_assignment.title} (BUS)"

# Math Assignment (Multi-department - assigned to both MATH and PHYS)
math_assignment = Assignment.find_or_create_by!(
  title: 'Calculus Problem Set',
  user: multi_teacher
) do |a|
  a.description = 'Complete problems 1-20 from Chapter 5. Show all work for partial credit.'
  a.due_date = 5.days.from_now
  a.points = 75
  a.category = 'homework'
  a.course_name = 'MATH 202'
  a.department = departments['MATH']
end
# Assign to both MATH and PHYS departments
math_assignment.assign_to_departments(departments['PHYS'])
puts "   ✅ Assignment: #{math_assignment.title} (MATH, PHYS)"

# Sample Notes
cs_note = Note.find_or_create_by!(
  title: 'Introduction to Algorithms',
  user: cs_student1
) do |n|
  n.content = "# Algorithms Overview\n\nAlgorithms are step-by-step procedures for solving problems.\n\n## Key Concepts:\n- Time Complexity (Big O)\n- Space Complexity\n- Sorting Algorithms\n- Search Algorithms\n\n## Big O Notation:\n- O(1): Constant time\n- O(log n): Logarithmic\n- O(n): Linear\n- O(n²): Quadratic"
  n.department = departments['CS']
end
puts "   ✅ Note: #{cs_note.title} (CS)"

bus_note = Note.find_or_create_by!(
  title: 'Marketing Principles',
  user: bus_student
) do |n|
  n.content = "# Marketing Fundamentals\n\n## The 4 Ps of Marketing:\n1. **Product**: What you're selling\n2. **Price**: How much it costs\n3. **Place**: Where you sell it\n4. **Promotion**: How you advertise\n\n## Market Segmentation:\n- Demographics\n- Psychographics\n- Geographic\n- Behavioral"
  n.department = departments['BUS']
end
puts "   ✅ Note: #{bus_note.title} (BUS)"

# Sample Quiz
cs_quiz = Quiz.find_or_create_by!(
  title: 'Algorithm Basics Quiz',
  user: cs_tutor
) do |q|
  q.description = 'Test your knowledge of basic algorithm concepts'
  q.difficulty = 'medium'
  q.status = 'published'
  q.department = departments['CS']
  q.note = cs_note
end
puts "   ✅ Quiz: #{cs_quiz.title} (CS)"

# Sample Learning Insights
puts "\n🧠 Creating Sample Learning Insights..."

# At-risk prediction for CS student
at_risk_insight = LearningInsight.find_or_create_by!(
  title: 'At-Risk Student Alert',
  user: cs_student1
) do |insight|
  insight.description = 'Alice Smith shows declining performance patterns and may need intervention'
  insight.insight_type = 'at_risk_prediction'
  insight.priority = 'high'
  insight.status = 'active'
  insight.confidence_score = 0.85
  insight.department = departments['CS']
  insight.data = {
    risk_score: 0.78,
    risk_factors: ['Late assignments', 'Declining grades', 'Low engagement'],
    predicted_outcome: 'Academic probation risk'
  }
  insight.metadata = {
    generated_at: Time.current.iso8601,
    algorithm_version: '1.0',
    supporting_evidence: [
      'Assignment submission rate dropped to 60%',
      'Quiz scores declined by 25% over last month',
      'No recent participation in class discussions'
    ],
    recommendation_actions: [
      'Schedule one-on-one meeting with student',
      'Connect with academic advisor',
      'Recommend tutoring support'
    ],
    related_metrics: {
      'submission_rate' => '60%',
      'average_score' => '72%',
      'engagement_score' => '3.2/10'
    }
  }
end
puts "   ✅ At-Risk Insight: #{at_risk_insight.title} (Alice Smith)"

# Performance decline for Business student
performance_insight = LearningInsight.find_or_create_by!(
  title: 'Performance Decline Detected',
  user: bus_student
) do |insight|
  insight.description = 'Carol Williams showing consistent decline in assignment quality and submission timeliness'
  insight.insight_type = 'performance_decline'
  insight.priority = 'medium'
  insight.status = 'active'
  insight.confidence_score = 0.72
  insight.department = departments['BUS']
  insight.data = {
    decline_percentage: 0.35,
    affected_areas: ['Assignment quality', 'Submission timeliness', 'Class participation'],
    trend_duration: '3 weeks'
  }
  insight.metadata = {
    generated_at: Time.current.iso8601,
    supporting_evidence: [
      'Average assignment score dropped from 88% to 65%',
      '40% of recent assignments submitted late',
      'Participation in class discussions decreased'
    ],
    recommendation_actions: [
      'Review study habits and time management',
      'Provide feedback on recent assignments',
      'Consider peer study group participation'
    ],
    related_metrics: {
      'score_trend' => '-23%',
      'on_time_submissions' => '60%',
      'participation_score' => '5.5/10'
    }
  }
end
puts "   ✅ Performance Decline Insight: #{performance_insight.title} (Carol Williams)"

# Engagement drop for Math student
engagement_insight = LearningInsight.find_or_create_by!(
  title: 'Student Engagement Concerns',
  user: math_student
) do |insight|
  insight.description = 'David Brown showing reduced engagement in course activities and discussions'
  insight.insight_type = 'engagement_drop'
  insight.priority = 'medium'
  insight.status = 'active'
  insight.confidence_score = 0.68
  insight.department = departments['MATH']
  insight.data = {
    engagement_score: 0.45,
    previous_score: 0.78,
    decline_areas: ['Forum participation', 'Office hours attendance', 'Quiz attempts']
  }
  insight.metadata = {
    generated_at: Time.current.iso8601,
    supporting_evidence: [
      'Forum posts decreased by 60% this month',
      'No office hours attendance in 2 weeks',
      'Quiz attempts declining (3 missed attempts)'
    ],
    recommendation_actions: [
      'Reach out to understand any external factors',
      'Encourage participation in study groups',
      'Provide flexible engagement options'
    ],
    related_metrics: {
      'forum_posts' => '2 this month',
      'office_hours' => '0 visits',
      'quiz_participation' => '70%'
    }
  }
end
puts "   ✅ Engagement Drop Insight: #{engagement_insight.title} (David Brown)"

# Learning style mismatch for second CS student
learning_style_insight = LearningInsight.find_or_create_by!(
  title: 'Learning Style Optimization Opportunity',
  user: cs_student2
) do |insight|
  insight.description = 'Bob Jones may benefit from visual learning approaches for better comprehension'
  insight.insight_type = 'learning_style_mismatch'
  insight.priority = 'low'
  insight.status = 'active'
  insight.confidence_score = 0.65
  insight.department = departments['CS']
  insight.data = {
    preferred_style: 'visual',
    current_approach: 'text-based',
    improvement_potential: 0.25
  }
  insight.metadata = {
    generated_at: Time.current.iso8601,
    supporting_evidence: [
      'Better performance on diagram-based questions',
      'Struggles with text-heavy explanations',
      'High engagement with video tutorials'
    ],
    recommendation_actions: [
      'Incorporate more visual aids in explanations',
      'Recommend coding visualization tools',
      'Suggest mind mapping for complex concepts'
    ],
    related_metrics: {
      'visual_question_score' => '89%',
      'text_question_score' => '71%',
      'video_engagement' => '95%'
    }
  }
end
puts "   ✅ Learning Style Insight: #{learning_style_insight.title} (Bob Jones)"

# Content difficulty insight
content_difficulty_insight = LearningInsight.find_or_create_by!(
  title: 'Course Content Difficulty Analysis',
  user: cs_student1
) do |insight|
  insight.description = 'Data Structures module showing higher than expected difficulty for current skill level'
  insight.insight_type = 'content_difficulty'
  insight.priority = 'medium'
  insight.status = 'active'
  insight.confidence_score = 0.79
  insight.department = departments['CS']
  insight.data = {
    difficulty_rating: 0.82,
    expected_rating: 0.65,
    struggling_topics: ['Binary Trees', 'Graph Algorithms', 'Dynamic Programming']
  }
  insight.metadata = {
    generated_at: Time.current.iso8601,
    supporting_evidence: [
      'Significantly lower scores on tree-related problems',
      'Multiple attempts needed for graph assignments',
      'Help-seeking behavior increased 150%'
    ],
    recommendation_actions: [
      'Provide additional practice problems with solutions',
      'Schedule review session for struggling topics',
      'Connect with peer mentors for support'
    ],
    related_metrics: {
      'tree_problems_score' => '45%',
      'help_requests' => '12 this week',
      'completion_time' => '180% of average'
    }
  }
end
puts "   ✅ Content Difficulty Insight: #{content_difficulty_insight.title} (Alice Smith)"

puts "\n✨ Seed completed successfully!"
puts "\n📊 Summary:"
puts "   • Departments: #{Department.count}"
puts "   • Users: #{User.count}"
puts "   • Assignments: #{Assignment.count}"
puts "   • Notes: #{Note.count}"
puts "   • Quizzes: #{Quiz.count}"

# Create Sample Courses
puts "\n📚 Creating Sample Courses..."
cs_dept = Department.find_by(code: 'CS')
math_dept = Department.find_by(code: 'MATH')
bus_dept = Department.find_by(code: 'BUS')

courses_data = [
  {
    code: '101',
    name: 'Introduction to Programming',
    description: 'Learn the fundamentals of programming using Python. Covers variables, loops, functions, and basic data structures.',
    department: cs_dept,
    credits: 3,
    level: 'freshman',
    delivery_method: 'in_person',
    max_students: 30,
    active: true
  },
  {
    code: '201',
    name: 'Data Structures and Algorithms',
    description: 'Advanced course covering arrays, linked lists, trees, graphs, sorting and searching algorithms.',
    department: cs_dept,
    credits: 4,
    level: 'sophomore',
    delivery_method: 'in_person',
    max_students: 25,
    active: true
  },
  {
    code: '301',
    name: 'Web Development',
    description: 'Build modern web applications with HTML, CSS, JavaScript, and Ruby on Rails.',
    department: cs_dept,
    credits: 3,
    level: 'junior',
    delivery_method: 'hybrid',
    max_students: 20,
    active: true
  },
  {
    code: '101',
    name: 'Calculus I',
    description: 'Introduction to differential and integral calculus.',
    department: math_dept,
    credits: 4,
    level: 'freshman',
    delivery_method: 'in_person',
    max_students: 35,
    active: true
  },
  {
    code: '201',
    name: 'Linear Algebra',
    description: 'Study of vector spaces, matrices, and linear transformations.',
    department: math_dept,
    credits: 3,
    level: 'sophomore',
    delivery_method: 'in_person',
    max_students: 30,
    active: true
  },
  {
    code: '101',
    name: 'Introduction to Business',
    description: 'Overview of business fundamentals including marketing, finance, and management.',
    department: bus_dept,
    credits: 3,
    level: 'freshman',
    delivery_method: 'online',
    max_students: 40,
    active: true
  }
]

courses_data.each do |course_data|
  course = Course.find_or_create_by!(
    code: course_data[:code],
    department_id: course_data[:department].id
  ) do |c|
    c.name = course_data[:name]
    c.description = course_data[:description]
    c.credits = course_data[:credits]
    c.level = course_data[:level]
    c.delivery_method = course_data[:delivery_method]
    c.max_students = course_data[:max_students]
    c.active = course_data[:active]
  end
  puts "   ✅ Created course: #{course.full_code} - #{course.name}"
end

# Create Sample Schedules
puts "\n📅 Creating Sample Schedules..."
teacher = User.find_by(email: 'frank.teacher@unihub.edu')
multi_teacher = User.find_by(email: 'grace.multiprof@unihub.edu')

schedules_data = [
  {
    title: 'Intro to Programming - Section A',
    course: 'CS-101',
    instructor: teacher,
    department: cs_dept,
    day_of_week: 1, # Monday
    start_time: Time.parse('09:00'),
    end_time: Time.parse('10:30'),
    room: 'CS Building - Room 101',
    recurring: true,
    color: '#3B82F6'
  },
  {
    title: 'Intro to Programming - Section B',
    course: 'CS-101',
    instructor: multi_teacher,
    department: cs_dept,
    day_of_week: 3, # Wednesday
    start_time: Time.parse('14:00'),
    end_time: Time.parse('15:30'),
    room: 'CS Building - Room 102',
    recurring: true,
    color: '#10B981'
  },
  {
    title: 'Data Structures',
    course: 'CS-201',
    instructor: teacher,
    department: cs_dept,
    day_of_week: 2, # Tuesday
    start_time: Time.parse('10:00'),
    end_time: Time.parse('11:30'),
    room: 'CS Building - Room 201',
    recurring: true,
    color: '#8B5CF6'
  },
  {
    title: 'Web Development',
    course: 'CS-301',
    instructor: multi_teacher,
    department: cs_dept,
    day_of_week: 4, # Thursday
    start_time: Time.parse('13:00'),
    end_time: Time.parse('15:00'),
    room: 'CS Building - Lab 1',
    recurring: true,
    color: '#F59E0B'
  },
  {
    title: 'Calculus I',
    course: 'MATH-101',
    instructor: multi_teacher,
    department: math_dept,
    day_of_week: 1, # Monday
    start_time: Time.parse('11:00'),
    end_time: Time.parse('12:30'),
    room: 'Math Building - Room 301',
    recurring: true,
    color: '#EF4444'
  },
  {
    title: 'Introduction to Business',
    course: 'BUS-101',
    instructor: teacher,
    department: bus_dept,
    day_of_week: 5, # Friday
    start_time: Time.parse('09:00'),
    end_time: Time.parse('11:00'),
    room: 'Business Hall - Auditorium',
    recurring: true,
    color: '#06B6D4'
  }
]

schedules_data.each do |schedule_data|
  schedule = Schedule.find_or_create_by!(
    course: schedule_data[:course],
    day_of_week: schedule_data[:day_of_week],
    start_time: schedule_data[:start_time]
  ) do |s|
    s.title = schedule_data[:title]
    s.description = "#{schedule_data[:course]} course offering"
    s.instructor_id = schedule_data[:instructor].id
    s.user_id = schedule_data[:instructor].id
    s.department_id = schedule_data[:department].id
    s.end_time = schedule_data[:end_time]
    s.room = schedule_data[:room]
    s.recurring = schedule_data[:recurring]
    s.color = schedule_data[:color]
  end
  puts "   ✅ Created schedule: #{schedule.course} - #{schedule.day_name} #{schedule.formatted_time_range}"
end

puts "\n📊 Final Statistics:"
puts "   • Departments: #{Department.count}"
puts "   • Users: #{User.count}"
puts "   • Courses: #{Course.count}"
puts "   • Schedules: #{Schedule.count}"
puts "   • Assignments: #{Assignment.count}"
puts "   • Notes: #{Note.count}"
puts "   • Quizzes: #{Quiz.count}"
puts "\n🔑 Admin Credentials:"
puts "   • Admin: osmanjalloh098@gmail.com (password: 012198_Oj)"
puts "\n🔑 Test User Credentials (all passwords: password123):"
puts "   • CS Student: alice.smith@unihub.edu"
puts "   • CS Student: bob.jones@unihub.edu"
puts "   • Business Student: carol.williams@unihub.edu"
puts "   • Math Student: david.brown@unihub.edu"
puts "   • CS Tutor: emma.tutor@unihub.edu"
puts "   • Business Teacher: frank.teacher@unihub.edu"
puts "   • Multi-Dept Teacher: grace.multiprof@unihub.edu"
puts "\n🎓 Ready to test! Students can now enroll in courses at /enrollments/new"
puts "🔐 Admins can manage courses at /admin and users at /admin/user_management"