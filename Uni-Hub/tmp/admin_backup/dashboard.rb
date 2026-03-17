# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # Welcome Section
    div class: "dashboard_welcome" do
      h2 "Welcome to Uni-Hub Administration", style: "font-size: 28px; margin-bottom: 10px; color: #333;"
      para "Manage courses, schedules, and university operations from this central dashboard.", style: "color: #666; font-size: 16px;"
    end

    # Quick Action Cards
    div style: "margin: 30px 0;" do
      columns do
        column do
          panel "📚 Course Management", style: "border-left: 4px solid #3B82F6;" do
            div style: "padding: 20px;" do
              h3 "Manage Course Catalog", style: "margin-bottom: 15px; color: #1F2937;"
              para "Create, edit, and manage official university courses. Control course availability and settings.", style: "margin-bottom: 20px; color: #6B7280; line-height: 1.6;"
              
              div style: "margin-top: 20px;" do
                span link_to("📖 View All Courses", admin_courses_path, 
                  class: "button", 
                  style: "background: #3B82F6; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block; margin-right: 10px;")
                span link_to("➕ Create New Course", new_admin_course_path, 
                  class: "button", 
                  style: "background: #10B981; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block;")
              end
              
              div style: "margin-top: 20px; padding-top: 20px; border-top: 1px solid #E5E7EB;" do
                para do
                  strong "Total Courses: "
                  text_node Course.count.to_s
                end
                para do
                  strong "Active Courses: "
                  text_node Course.active.count.to_s
                end
              end
            end
          end
        end

        column do
          panel "📅 Schedule Management", style: "border-left: 4px solid #8B5CF6;" do
            div style: "padding: 20px;" do
              h3 "Manage Course Schedules", style: "margin-bottom: 15px; color: #1F2937;"
              para "Create course schedules, assign instructors, and manage class timings.", style: "margin-bottom: 20px; color: #6B7280; line-height: 1.6;"
              
              div style: "margin-top: 20px;" do
                span link_to("📋 View All Schedules", admin_schedules_path, 
                  class: "button", 
                  style: "background: #8B5CF6; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block; margin-right: 10px;")
                span link_to("➕ Create New Schedule", new_admin_schedule_path, 
                  class: "button", 
                  style: "background: #10B981; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block;")
              end
              
              div style: "margin-top: 20px; padding-top: 20px; border-top: 1px solid #E5E7EB;" do
                para do
                  strong "Total Schedules: "
                  text_node Schedule.count.to_s
                end
                para do
                  strong "Total Enrollments: "
                  text_node Enrollment.active.count.to_s
                end
              end
            end
          end
        end
      end

      # Second Row
      columns do
        column do
          panel "👥 User Management", style: "border-left: 4px solid #F59E0B;" do
            div style: "padding: 20px;" do
              h3 "Manage Users & Roles", style: "margin-bottom: 15px; color: #1F2937;"
              para "View and manage students, teachers, and administrators.", style: "margin-bottom: 20px; color: #6B7280; line-height: 1.6;"
              
              div style: "margin-top: 20px;" do
                span link_to("👤 View All Users", admin_users_path, 
                  class: "button", 
                  style: "background: #F59E0B; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block;")
              end
              
              div style: "margin-top: 20px; padding-top: 20px; border-top: 1px solid #E5E7EB;" do
                para do
                  strong "Total Users: "
                  text_node User.count.to_s
                end
                para do
                  strong "Students: "
                  text_node User.where(role: 'student').count.to_s
                end
                para do
                  strong "Teachers: "
                  text_node User.where(role: 'teacher').count.to_s
                end
              end
            end
          end
        end

        column do
          panel "🏢 Department Management", style: "border-left: 4px solid #EF4444;" do
            div style: "padding: 20px;" do
              h3 "Manage Departments", style: "margin-bottom: 15px; color: #1F2937;"
              para "View and manage university departments and organizational structure.", style: "margin-bottom: 20px; color: #6B7280; line-height: 1.6;"
              
              div style: "margin-top: 20px;" do
                span link_to("🏛️ View Departments", admin_departments_path, 
                  class: "button", 
                  style: "background: #EF4444; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; display: inline-block;")
              end
              
              div style: "margin-top: 20px; padding-top: 20px; border-top: 1px solid #E5E7EB;" do
                para do
                  strong "Total Departments: "
                  text_node Department.count.to_s
                end
                para do
                  strong "Active Departments: "
                  text_node Department.where(active: true).count.to_s
                end
              end
            end
          end
        end
      end
    end

    # Recent Activity Section
    columns do
      column do
        panel "📊 Recent Courses", style: "border-left: 4px solid #06B6D4;" do
          table_for Course.order(created_at: :desc).limit(5) do
            column "Code" do |course|
              link_to course.full_code, admin_course_path(course)
            end
            column "Name", :name
            column "Department" do |course|
              course.department.name
            end
            column "Status" do |course|
              status_tag(course.active? ? "Active" : "Inactive", course.active? ? :ok : :error)
            end
          end
        end
      end

      column do
        panel "🎓 Recent Schedules", style: "border-left: 4px solid #14B8A6;" do
          table_for Schedule.order(created_at: :desc).limit(5) do
            column "Course", :course
            column "Instructor" do |schedule|
              schedule.instructor&.email || "Unassigned"
            end
            column "Day" do |schedule|
              schedule.day_name
            end
            column "Time" do |schedule|
              schedule.formatted_time_range
            end
          end
        end
      end
    end
  end # content
end
