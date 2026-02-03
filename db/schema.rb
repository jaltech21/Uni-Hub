# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_22_143955) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_audit_logs", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "action"
    t.string "target_type"
    t.integer "target_id"
    t.jsonb "details"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["admin_id"], name: "index_admin_audit_logs_on_admin_id"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_admin_audit_logs_on_target_type_and_target_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "ai_grading_results", force: :cascade do |t|
    t.bigint "submission_id", null: false
    t.bigint "grading_rubric_id", null: false
    t.decimal "ai_score", precision: 8, scale: 2
    t.decimal "confidence_score", precision: 5, scale: 3
    t.text "ai_feedback"
    t.string "processing_status", default: "pending"
    t.datetime "processed_at"
    t.boolean "requires_review", default: false
    t.string "review_status", default: "pending"
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "instructor_notes"
    t.string "ai_provider", default: "openai"
    t.integer "processing_time_seconds"
    t.text "error_message"
    t.json "detailed_scores"
    t.boolean "grade_applied", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_ai_grading_results_on_confidence_score"
    t.index ["grading_rubric_id"], name: "index_ai_grading_results_on_grading_rubric_id"
    t.index ["processed_at"], name: "index_ai_grading_results_on_processed_at"
    t.index ["processing_status"], name: "index_ai_grading_results_on_processing_status"
    t.index ["requires_review"], name: "index_ai_grading_results_on_requires_review"
    t.index ["review_status"], name: "index_ai_grading_results_on_review_status"
    t.index ["reviewed_by_id"], name: "index_ai_grading_results_on_reviewed_by_id"
    t.index ["submission_id", "grading_rubric_id"], name: "idx_on_submission_id_grading_rubric_id_c30b48345d", unique: true
    t.index ["submission_id"], name: "index_ai_grading_results_on_submission_id"
  end

  create_table "ai_usage_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action"
    t.string "status"
    t.text "request_details"
    t.text "response_details"
    t.text "error_message"
    t.float "processing_time"
    t.integer "tokens_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider", default: "unknown"
    t.index ["provider"], name: "index_ai_usage_logs_on_provider"
    t.index ["user_id"], name: "index_ai_usage_logs_on_user_id"
  end

  create_table "analytics_dashboards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.string "title"
    t.string "dashboard_type"
    t.text "layout_config"
    t.text "filter_config"
    t.text "permissions_config"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_analytics_dashboards_on_department_id"
    t.index ["user_id"], name: "index_analytics_dashboards_on_user_id"
  end

  create_table "analytics_metrics", force: :cascade do |t|
    t.string "metric_name"
    t.string "metric_type"
    t.string "entity_type"
    t.integer "entity_id"
    t.decimal "value"
    t.json "metadata"
    t.datetime "recorded_at", precision: nil
    t.bigint "campus_id"
    t.bigint "department_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id"], name: "index_analytics_metrics_on_campus_id"
    t.index ["department_id"], name: "index_analytics_metrics_on_department_id"
    t.index ["entity_type", "entity_id"], name: "index_analytics_metrics_on_entity_type_and_entity_id"
    t.index ["metric_name", "recorded_at"], name: "index_analytics_metrics_on_metric_name_and_recorded_at"
    t.index ["metric_type"], name: "index_analytics_metrics_on_metric_type"
    t.index ["recorded_at"], name: "index_analytics_metrics_on_recorded_at"
    t.index ["user_id"], name: "index_analytics_metrics_on_user_id"
  end

  create_table "analytics_reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.bigint "analytics_dashboard_id", null: false
    t.string "title"
    t.string "report_type"
    t.string "status"
    t.text "config"
    t.text "filters"
    t.text "data"
    t.text "metadata"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analytics_dashboard_id"], name: "index_analytics_reports_on_analytics_dashboard_id"
    t.index ["department_id"], name: "index_analytics_reports_on_department_id"
    t.index ["user_id"], name: "index_analytics_reports_on_user_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.string "priority", default: "normal", null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "expires_at"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id", "pinned", "published_at"], name: "idx_on_department_id_pinned_published_at_e5f4750e27"
    t.index ["department_id", "priority"], name: "index_announcements_on_department_id_and_priority"
    t.index ["department_id"], name: "index_announcements_on_department_id"
    t.index ["user_id"], name: "index_announcements_on_user_id"
  end

  create_table "assignment_departments", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "shared_by_id"
    t.string "permission_level", default: "view", null: false
    t.index ["assignment_id", "department_id"], name: "index_assignment_departments_unique", unique: true
    t.index ["assignment_id"], name: "index_assignment_departments_on_assignment_id"
    t.index ["department_id"], name: "index_assignment_departments_on_department_id"
    t.index ["shared_by_id"], name: "index_assignment_departments_on_shared_by_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "due_date"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "points", default: 100
    t.string "category", default: "homework"
    t.text "grading_criteria"
    t.boolean "allow_resubmission", default: false
    t.string "course_name"
    t.bigint "department_id"
    t.bigint "schedule_id"
    t.index ["department_id", "created_at"], name: "index_assignments_on_department_id_and_created_at"
    t.index ["department_id"], name: "index_assignments_on_department_id"
    t.index ["schedule_id", "created_at"], name: "index_assignments_on_schedule_id_and_created_at"
    t.index ["schedule_id", "due_date"], name: "index_assignments_on_schedule_id_and_due_date"
    t.index ["schedule_id"], name: "index_assignments_on_schedule_id"
    t.index ["user_id"], name: "index_assignments_on_user_id"
  end

  create_table "attendance_lists", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "date"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "secret_key", limit: 32, null: false
    t.index ["user_id"], name: "index_attendance_lists_on_user_id"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.bigint "attendance_list_id", null: false
    t.bigint "user_id", null: false
    t.boolean "present"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attendance_list_id"], name: "index_attendance_records_on_attendance_list_id"
    t.index ["user_id"], name: "index_attendance_records_on_user_id"
  end

  create_table "audit_trails", force: :cascade do |t|
    t.bigint "user_id"
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", limit: 50, null: false
    t.json "change_details", default: {}
    t.json "metadata", default: {}
    t.string "ip_address", limit: 45
    t.string "user_agent", limit: 500
    t.string "session_id", limit: 255
    t.string "request_method", limit: 10
    t.string "request_path", limit: 500
    t.integer "response_status"
    t.string "severity", limit: 20, default: "info"
    t.boolean "security_event", default: false
    t.text "error_message"
    t.string "transaction_id", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_trails_on_action"
    t.index ["auditable_type", "auditable_id"], name: "idx_audit_trails_auditable"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_trails_on_auditable"
    t.index ["created_at"], name: "index_audit_trails_on_created_at"
    t.index ["security_event"], name: "index_audit_trails_on_security_event"
    t.index ["user_id", "created_at"], name: "idx_audit_trails_user_time"
    t.index ["user_id"], name: "idx_audit_trails_user"
    t.index ["user_id"], name: "index_audit_trails_on_user_id"
  end

  create_table "business_intelligence_reports", force: :cascade do |t|
    t.string "report_name"
    t.string "report_type"
    t.string "report_period"
    t.bigint "generated_by_id", null: false
    t.json "data_sources"
    t.json "insights"
    t.json "recommendations"
    t.text "executive_summary"
    t.string "status", default: "generating"
    t.datetime "generated_at", precision: nil
    t.bigint "campus_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id"], name: "index_business_intelligence_reports_on_campus_id"
    t.index ["generated_at"], name: "index_business_intelligence_reports_on_generated_at"
    t.index ["generated_by_id"], name: "index_business_intelligence_reports_on_generated_by_id"
    t.index ["report_type", "generated_at"], name: "idx_on_report_type_generated_at_4391f326e5"
    t.index ["status"], name: "index_business_intelligence_reports_on_status"
  end

  create_table "campus_programs", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", limit: 20, null: false
    t.text "description"
    t.string "degree_level", null: false
    t.integer "duration_months", null: false
    t.integer "credits_required", null: false
    t.bigint "campus_id", null: false
    t.bigint "department_id", null: false
    t.boolean "active", default: true
    t.decimal "tuition_per_credit", precision: 8, scale: 2
    t.integer "max_enrollment"
    t.integer "current_enrollment", default: 0
    t.date "program_start_date"
    t.string "delivery_method"
    t.text "admission_requirements"
    t.text "graduation_requirements"
    t.json "program_outcomes"
    t.string "accreditation_body"
    t.date "last_accredited"
    t.date "next_review_date"
    t.bigint "program_director_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id", "code"], name: "index_campus_programs_on_campus_id_and_code", unique: true
    t.index ["campus_id", "degree_level"], name: "index_campus_programs_on_campus_id_and_degree_level"
    t.index ["campus_id"], name: "index_campus_programs_on_campus_id"
    t.index ["delivery_method"], name: "index_campus_programs_on_delivery_method"
    t.index ["department_id", "active"], name: "index_campus_programs_on_department_id_and_active"
    t.index ["department_id"], name: "index_campus_programs_on_department_id"
    t.index ["program_director_id"], name: "idx_campus_programs_director"
    t.index ["program_director_id"], name: "index_campus_programs_on_program_director_id"
  end

  create_table "campuses", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", limit: 10, null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "timezone", default: "UTC"
    t.boolean "is_main_campus", default: false
    t.boolean "active", default: true
    t.bigint "university_id", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.integer "student_capacity"
    t.integer "faculty_count", default: 0
    t.integer "staff_count", default: 0
    t.date "established_date"
    t.text "facilities_description"
    t.string "accreditation_status"
    t.json "contact_persons"
    t.json "operating_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_campuses_on_active"
    t.index ["established_date"], name: "index_campuses_on_established_date"
    t.index ["latitude", "longitude"], name: "index_campuses_on_latitude_and_longitude"
    t.index ["university_id", "code"], name: "index_campuses_on_university_id_and_code", unique: true
    t.index ["university_id", "is_main_campus"], name: "index_campuses_on_university_id_and_is_main_campus"
    t.index ["university_id"], name: "index_campuses_on_university_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.bigint "recipient_id", null: false
    t.text "content"
    t.string "message_type"
    t.integer "thread_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_chat_messages_on_created_at"
    t.index ["read_at"], name: "index_chat_messages_on_read_at"
    t.index ["recipient_id"], name: "index_chat_messages_on_recipient_id"
    t.index ["sender_id", "recipient_id"], name: "index_chat_messages_on_sender_id_and_recipient_id"
    t.index ["sender_id"], name: "index_chat_messages_on_sender_id"
    t.index ["thread_id"], name: "index_chat_messages_on_thread_id"
  end

  create_table "collaboration_events", force: :cascade do |t|
    t.bigint "collaborative_session_id", null: false
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.string "event_category", default: "general"
    t.integer "severity", default: 0
    t.json "event_data", default: {}
    t.text "description"
    t.string "summary", limit: 500
    t.bigint "related_operation_id"
    t.string "related_entity_type"
    t.bigint "related_entity_id"
    t.datetime "event_timestamp", precision: nil, null: false
    t.string "source", default: "system"
    t.string "client_info"
    t.boolean "is_processed", default: false
    t.datetime "processed_at", precision: nil
    t.json "processing_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaborative_session_id", "event_timestamp"], name: "idx_collab_events_session_time"
    t.index ["collaborative_session_id"], name: "index_collaboration_events_on_collaborative_session_id"
    t.index ["event_type", "event_timestamp"], name: "idx_collab_events_type_time"
    t.index ["related_entity_type", "related_entity_id"], name: "idx_collab_events_related_entity"
    t.index ["related_operation_id"], name: "index_collaboration_events_on_related_operation_id"
    t.index ["severity", "is_processed"], name: "idx_collab_events_severity_processing"
    t.index ["user_id", "event_timestamp"], name: "idx_collab_events_user_time"
    t.index ["user_id"], name: "index_collaboration_events_on_user_id"
  end

  create_table "collaboration_milestones", force: :cascade do |t|
    t.bigint "cross_campus_collaboration_id", null: false
    t.string "title", limit: 255, null: false
    t.text "description"
    t.date "due_date", null: false
    t.string "status", limit: 30, default: "pending", null: false
    t.datetime "completed_at"
    t.integer "priority", default: 1
    t.decimal "completion_percentage", precision: 5, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cross_campus_collaboration_id"], name: "idx_milestones_on_collaboration"
    t.index ["due_date"], name: "index_collaboration_milestones_on_due_date"
    t.index ["priority"], name: "index_collaboration_milestones_on_priority"
    t.index ["status", "due_date"], name: "idx_milestones_status_due_date"
    t.index ["status"], name: "index_collaboration_milestones_on_status"
  end

  create_table "collaboration_participants", force: :cascade do |t|
    t.bigint "cross_campus_collaboration_id", null: false
    t.bigint "user_id", null: false
    t.string "role", limit: 50, null: false
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cross_campus_collaboration_id", "user_id"], name: "idx_unique_collaboration_participant", unique: true
    t.index ["cross_campus_collaboration_id"], name: "idx_collab_participants_on_collaboration"
    t.index ["joined_at"], name: "index_collaboration_participants_on_joined_at"
    t.index ["role"], name: "index_collaboration_participants_on_role"
    t.index ["status"], name: "index_collaboration_participants_on_status"
    t.index ["user_id"], name: "index_collaboration_participants_on_user_id"
  end

  create_table "collaboration_resources", force: :cascade do |t|
    t.bigint "cross_campus_collaboration_id", null: false
    t.string "resource_type", limit: 50, null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.string "url", limit: 500
    t.boolean "is_public", default: false
    t.decimal "file_size_mb", precision: 10, scale: 2
    t.string "access_level", limit: 30, default: "collaboration_only"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_level"], name: "index_collaboration_resources_on_access_level"
    t.index ["cross_campus_collaboration_id"], name: "idx_resources_on_collaboration"
    t.index ["is_public"], name: "index_collaboration_resources_on_is_public"
    t.index ["resource_type", "is_public"], name: "idx_resources_type_public"
    t.index ["resource_type"], name: "index_collaboration_resources_on_resource_type"
  end

  create_table "collaborative_sessions", force: :cascade do |t|
    t.string "collaboratable_type", null: false
    t.bigint "collaboratable_id", null: false
    t.bigint "created_by_id", null: false
    t.string "session_token", null: false
    t.string "session_name", limit: 200
    t.text "description"
    t.integer "status", default: 0, null: false
    t.integer "permission_level", default: 2
    t.integer "max_participants", default: 10
    t.datetime "started_at", precision: nil
    t.datetime "ended_at", precision: nil
    t.datetime "last_activity_at", precision: nil
    t.json "snapshot_data", default: {}
    t.datetime "last_snapshot_at", precision: nil
    t.integer "current_version", default: 1
    t.boolean "auto_save_enabled", default: true
    t.integer "auto_save_interval", default: 30
    t.boolean "conflict_resolution_enabled", default: true
    t.string "conflict_resolution_strategy", default: "operational_transform"
    t.integer "total_edits", default: 0
    t.integer "total_comments", default: 0
    t.integer "total_conflicts_resolved", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaboratable_type", "collaboratable_id", "status"], name: "idx_collab_sessions_content_status"
    t.index ["collaboratable_type", "collaboratable_id"], name: "index_collaborative_sessions_on_collaboratable"
    t.index ["created_by_id", "status"], name: "idx_collab_sessions_creator_status"
    t.index ["created_by_id"], name: "index_collaborative_sessions_on_created_by_id"
    t.index ["last_activity_at"], name: "idx_collab_sessions_activity"
    t.index ["session_token"], name: "index_collaborative_sessions_on_session_token", unique: true
    t.index ["started_at", "ended_at"], name: "idx_collab_sessions_duration"
  end

  create_table "compliance_assessments", force: :cascade do |t|
    t.bigint "compliance_framework_id", null: false
    t.bigint "campus_id"
    t.bigint "department_id"
    t.string "assessment_type", limit: 50, null: false
    t.string "status", limit: 30, default: "scheduled", null: false
    t.decimal "score", precision: 5, scale: 2
    t.json "findings", default: []
    t.json "recommendations", default: []
    t.bigint "assessor_id", null: false
    t.date "assessment_date", null: false
    t.date "due_date"
    t.date "completion_date"
    t.text "executive_summary"
    t.json "evidence", default: []
    t.json "action_items", default: []
    t.integer "priority", default: 2
    t.boolean "passed", default: false
    t.text "assessor_notes"
    t.string "certification_status", limit: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_date"], name: "index_compliance_assessments_on_assessment_date"
    t.index ["assessment_type"], name: "index_compliance_assessments_on_assessment_type"
    t.index ["assessor_id"], name: "index_compliance_assessments_on_assessor_id"
    t.index ["campus_id"], name: "index_compliance_assessments_on_campus_id"
    t.index ["compliance_framework_id"], name: "index_compliance_assessments_on_compliance_framework_id"
    t.index ["department_id"], name: "index_compliance_assessments_on_department_id"
    t.index ["due_date"], name: "index_compliance_assessments_on_due_date"
    t.index ["passed"], name: "index_compliance_assessments_on_passed"
    t.index ["status", "due_date"], name: "idx_assessments_status_due"
    t.index ["status"], name: "index_compliance_assessments_on_status"
  end

  create_table "compliance_frameworks", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "framework_type", limit: 100, null: false
    t.string "regulatory_body", limit: 255, null: false
    t.string "version", limit: 50
    t.date "effective_date", null: false
    t.json "requirements", default: []
    t.json "assessment_criteria", default: {}
    t.string "reporting_frequency", limit: 50, null: false
    t.string "status", limit: 30, default: "active", null: false
    t.text "description"
    t.date "expiry_date"
    t.integer "assessment_cycle_months", default: 12
    t.decimal "compliance_threshold", precision: 5, scale: 2, default: "80.0"
    t.boolean "mandatory", default: true
    t.json "notification_settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effective_date"], name: "index_compliance_frameworks_on_effective_date"
    t.index ["framework_type", "status"], name: "idx_frameworks_type_status"
    t.index ["framework_type"], name: "index_compliance_frameworks_on_framework_type"
    t.index ["regulatory_body"], name: "index_compliance_frameworks_on_regulatory_body"
    t.index ["status"], name: "index_compliance_frameworks_on_status"
  end

  create_table "compliance_reports", force: :cascade do |t|
    t.bigint "compliance_framework_id", null: false
    t.bigint "campus_id"
    t.string "report_type", limit: 50, null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.bigint "generated_by_id", null: false
    t.string "status", limit: 30, default: "draft", null: false
    t.json "content", default: {}
    t.text "executive_summary"
    t.json "recommendations", default: []
    t.decimal "overall_compliance_score", precision: 5, scale: 2
    t.integer "total_assessments", default: 0
    t.integer "passed_assessments", default: 0
    t.json "key_metrics", default: {}
    t.json "trend_analysis", default: {}
    t.string "file_path", limit: 500
    t.boolean "auto_generated", default: false
    t.datetime "published_at"
    t.string "report_format", limit: 20, default: "pdf"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_generated"], name: "index_compliance_reports_on_auto_generated"
    t.index ["campus_id"], name: "index_compliance_reports_on_campus_id"
    t.index ["compliance_framework_id"], name: "index_compliance_reports_on_compliance_framework_id"
    t.index ["generated_by_id"], name: "index_compliance_reports_on_generated_by_id"
    t.index ["period_start", "period_end"], name: "idx_reports_period"
    t.index ["published_at"], name: "index_compliance_reports_on_published_at"
    t.index ["report_type"], name: "index_compliance_reports_on_report_type"
    t.index ["status"], name: "index_compliance_reports_on_status"
  end

  create_table "content_sharing_histories", force: :cascade do |t|
    t.string "shareable_type", null: false
    t.bigint "shareable_id", null: false
    t.bigint "department_id", null: false
    t.bigint "shared_by_id", null: false
    t.string "action", null: false
    t.string "permission_level"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_content_sharing_histories_on_created_at"
    t.index ["department_id"], name: "index_content_sharing_histories_on_department_id"
    t.index ["shareable_type", "shareable_id"], name: "index_content_sharing_histories_on_shareable"
    t.index ["shared_by_id"], name: "index_content_sharing_histories_on_shared_by_id"
  end

  create_table "content_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "template_type"
    t.text "content"
    t.json "metadata"
    t.string "visibility"
    t.bigint "created_by_id", null: false
    t.bigint "department_id"
    t.string "category"
    t.text "tags"
    t.boolean "is_featured"
    t.integer "usage_count"
    t.string "version"
    t.bigint "parent_template_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_content_templates_on_created_by_id"
    t.index ["department_id"], name: "index_content_templates_on_department_id"
    t.index ["parent_template_id"], name: "index_content_templates_on_parent_template_id"
  end

  create_table "content_versions", force: :cascade do |t|
    t.string "versionable_type", null: false
    t.bigint "versionable_id", null: false
    t.bigint "user_id", null: false
    t.bigint "parent_version_id"
    t.integer "version_number", null: false
    t.integer "patch_number", default: 0
    t.string "branch_name"
    t.string "version_tag"
    t.json "content_data", null: false
    t.json "metadata", default: {}
    t.json "diff_data", default: {}
    t.integer "status", default: 0, null: false
    t.integer "change_type", default: 0, null: false
    t.string "change_summary", limit: 500, null: false
    t.text "change_description"
    t.string "content_hash", null: false
    t.bigint "content_size", default: 0
    t.datetime "published_at", precision: nil
    t.bigint "published_by_id"
    t.integer "approval_status", default: 0
    t.bigint "approved_by_id"
    t.datetime "approved_at", precision: nil
    t.text "approval_notes"
    t.integer "views_count", default: 0
    t.integer "downloads_count", default: 0
    t.datetime "last_accessed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_content_versions_on_approved_by_id"
    t.index ["branch_name"], name: "index_content_versions_on_branch_name", where: "(branch_name IS NOT NULL)"
    t.index ["content_hash"], name: "index_content_versions_on_content_hash"
    t.index ["parent_version_id"], name: "index_content_versions_on_parent_version_id"
    t.index ["published_by_id"], name: "index_content_versions_on_published_by_id"
    t.index ["status", "published_at"], name: "idx_content_versions_published"
    t.index ["user_id", "created_at"], name: "idx_content_versions_user_timeline"
    t.index ["user_id"], name: "index_content_versions_on_user_id"
    t.index ["versionable_type", "versionable_id", "status"], name: "idx_content_versions_status"
    t.index ["versionable_type", "versionable_id", "version_number"], name: "idx_content_versions_unique_version", unique: true
    t.index ["versionable_type", "versionable_id"], name: "idx_content_versions_current_published", where: "(status = 1)"
    t.index ["versionable_type", "versionable_id"], name: "index_content_versions_on_versionable"
  end

  create_table "courses", force: :cascade do |t|
    t.string "code", limit: 20, null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.integer "credits", null: false
    t.integer "duration_weeks", default: 16
    t.string "level", limit: 30
    t.bigint "department_id", null: false
    t.boolean "active", default: true
    t.string "delivery_method", limit: 20, default: "in_person"
    t.json "prerequisites"
    t.decimal "tuition_cost", precision: 10, scale: 2
    t.integer "max_students"
    t.string "instructor_requirements", limit: 500
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_courses_on_active"
    t.index ["credits"], name: "index_courses_on_credits"
    t.index ["delivery_method"], name: "index_courses_on_delivery_method"
    t.index ["department_id", "code"], name: "idx_unique_course_code_per_department", unique: true
    t.index ["department_id"], name: "index_courses_on_department_id"
    t.index ["level"], name: "index_courses_on_level"
  end

  create_table "cross_campus_collaborations", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "collaboration_type", null: false
    t.bigint "initiating_campus_id", null: false
    t.json "participating_campuses"
    t.date "start_date"
    t.date "end_date"
    t.string "status", default: "planning"
    t.bigint "coordinator_id", null: false
    t.decimal "budget_allocated", precision: 12, scale: 2
    t.decimal "budget_spent", precision: 12, scale: 2, default: "0.0"
    t.text "objectives"
    t.text "expected_outcomes"
    t.json "milestones"
    t.json "resources_shared"
    t.integer "students_involved", default: 0
    t.integer "faculty_involved", default: 0
    t.text "success_metrics"
    t.text "challenges_faced"
    t.decimal "completion_percentage", precision: 5, scale: 2, default: "0.0"
    t.json "approval_workflow"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_cross_campus_collaborations_on_approved_by_id"
    t.index ["collaboration_type"], name: "idx_cross_campus_collab_type"
    t.index ["completion_percentage"], name: "idx_cross_campus_collab_completion"
    t.index ["coordinator_id"], name: "idx_cross_campus_collab_coordinator"
    t.index ["coordinator_id"], name: "index_cross_campus_collaborations_on_coordinator_id"
    t.index ["initiating_campus_id"], name: "index_cross_campus_collaborations_on_initiating_campus_id"
    t.index ["start_date", "end_date"], name: "idx_cross_campus_collab_dates"
    t.index ["status"], name: "idx_cross_campus_collab_status"
  end

  create_table "cursor_positions", force: :cascade do |t|
    t.bigint "collaborative_session_id", null: false
    t.bigint "user_id", null: false
    t.json "position_data", null: false
    t.string "content_path"
    t.integer "line_number"
    t.integer "column_number"
    t.integer "character_offset"
    t.json "selection_data"
    t.integer "selection_start"
    t.integer "selection_end"
    t.boolean "has_selection", default: false
    t.string "cursor_color"
    t.string "user_color"
    t.boolean "is_typing", default: false
    t.datetime "last_typing_at", precision: nil
    t.datetime "last_moved_at", precision: nil
    t.integer "movement_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaborative_session_id", "updated_at"], name: "idx_cursor_positions_session_activity"
    t.index ["collaborative_session_id", "user_id"], name: "idx_cursor_positions_unique", unique: true
    t.index ["collaborative_session_id"], name: "index_cursor_positions_on_collaborative_session_id"
    t.index ["content_path", "character_offset"], name: "idx_cursor_positions_content_location"
    t.index ["is_typing", "last_typing_at"], name: "idx_cursor_positions_typing_activity"
    t.index ["user_id"], name: "index_cursor_positions_on_user_id"
  end

  create_table "dashboard_widgets", force: :cascade do |t|
    t.bigint "analytics_dashboard_id", null: false
    t.string "widget_type"
    t.string "title"
    t.text "description"
    t.integer "position_x"
    t.integer "position_y"
    t.integer "width"
    t.integer "height"
    t.text "config"
    t.text "data_sources"
    t.text "filter_config"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analytics_dashboard_id"], name: "index_dashboard_widgets_on_analytics_dashboard_id"
  end

  create_table "department_member_histories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.string "action", null: false
    t.bigint "performed_by_id"
    t.jsonb "details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_department_member_histories_on_action"
    t.index ["created_at"], name: "index_department_member_histories_on_created_at"
    t.index ["department_id"], name: "index_department_member_histories_on_department_id"
    t.index ["performed_by_id"], name: "index_department_member_histories_on_performed_by_id"
    t.index ["user_id"], name: "index_department_member_histories_on_user_id"
  end

  create_table "department_settings", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.string "primary_color", default: "#3B82F6"
    t.string "secondary_color", default: "#10B981"
    t.string "logo_url"
    t.string "banner_url"
    t.text "welcome_message"
    t.text "footer_message"
    t.string "default_assignment_visibility", default: "department"
    t.string "default_note_visibility", default: "private"
    t.string "default_quiz_visibility", default: "department"
    t.json "assignment_templates", default: []
    t.json "quiz_templates", default: []
    t.boolean "enable_announcements", default: true
    t.boolean "enable_content_sharing", default: true
    t.boolean "enable_peer_review", default: false
    t.boolean "enable_gamification", default: false
    t.boolean "notify_new_members", default: true
    t.boolean "notify_new_content", default: true
    t.boolean "notify_submissions", default: true
    t.json "custom_fields", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_department_settings_on_department_id", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", limit: 10, null: false
    t.text "description"
    t.bigint "university_id"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "campus_id"
    t.index ["active"], name: "index_departments_on_active"
    t.index ["campus_id", "name"], name: "index_departments_on_campus_id_and_name"
    t.index ["campus_id"], name: "index_departments_on_campus_id"
    t.index ["university_id", "code"], name: "index_departments_on_university_id_and_code", unique: true
  end

  create_table "discussion_posts", force: :cascade do |t|
    t.bigint "discussion_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_discussion_posts_on_created_at"
    t.index ["discussion_id", "parent_id"], name: "index_discussion_posts_on_discussion_id_and_parent_id"
    t.index ["discussion_id"], name: "index_discussion_posts_on_discussion_id"
    t.index ["parent_id"], name: "index_discussion_posts_on_parent_id"
    t.index ["user_id"], name: "index_discussion_posts_on_user_id"
  end

  create_table "discussions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.bigint "user_id", null: false
    t.string "category", default: "general", null: false
    t.string "status", default: "open", null: false
    t.integer "views_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_discussions_on_category"
    t.index ["created_at"], name: "index_discussions_on_created_at"
    t.index ["status"], name: "index_discussions_on_status"
    t.index ["updated_at"], name: "index_discussions_on_updated_at"
    t.index ["user_id"], name: "index_discussions_on_user_id"
    t.index ["views_count"], name: "index_discussions_on_views_count"
  end

  create_table "edit_operations", force: :cascade do |t|
    t.bigint "collaborative_session_id", null: false
    t.bigint "user_id", null: false
    t.bigint "sequence_number", null: false
    t.string "operation_id", null: false
    t.bigint "parent_operation_id"
    t.string "operation_type", null: false
    t.json "operation_data", null: false
    t.json "transformed_data"
    t.string "content_path"
    t.integer "start_position"
    t.integer "end_position"
    t.integer "status", default: 0
    t.datetime "applied_at", precision: nil
    t.datetime "timestamp", precision: nil, null: false
    t.boolean "has_conflict", default: false
    t.json "conflict_data"
    t.string "resolution_strategy"
    t.bigint "resolved_by_id"
    t.datetime "resolved_at", precision: nil
    t.boolean "is_transformed", default: false
    t.json "transformation_log"
    t.integer "transform_generation", default: 0
    t.string "client_id"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaborative_session_id", "sequence_number"], name: "idx_edit_ops_session_sequence", unique: true
    t.index ["collaborative_session_id", "timestamp"], name: "idx_edit_ops_session_time"
    t.index ["collaborative_session_id"], name: "index_edit_operations_on_collaborative_session_id"
    t.index ["content_path", "start_position"], name: "idx_edit_ops_content_location"
    t.index ["has_conflict", "status"], name: "idx_edit_ops_conflicts"
    t.index ["operation_id"], name: "index_edit_operations_on_operation_id"
    t.index ["operation_type", "status"], name: "idx_edit_ops_type_status"
    t.index ["parent_operation_id"], name: "index_edit_operations_on_parent_operation_id"
    t.index ["resolved_by_id"], name: "index_edit_operations_on_resolved_by_id"
    t.index ["user_id", "timestamp"], name: "idx_edit_ops_user_time"
    t.index ["user_id"], name: "index_edit_operations_on_user_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "schedule_id", null: false
    t.datetime "enrollment_date", default: -> { "CURRENT_TIMESTAMP" }
    t.string "status", default: "active"
    t.string "academic_year"
    t.string "semester"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_year", "semester"], name: "index_enrollments_on_academic_year_and_semester"
    t.index ["schedule_id", "status"], name: "index_enrollments_on_schedule_id_and_status"
    t.index ["schedule_id"], name: "index_enrollments_on_schedule_id"
    t.index ["user_id", "schedule_id"], name: "index_enrollments_on_user_id_and_schedule_id", unique: true
    t.index ["user_id", "status"], name: "index_enrollments_on_user_id_and_status"
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "equipment", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.string "equipment_type", limit: 100, null: false
    t.string "brand", limit: 100
    t.string "model", limit: 100
    t.bigint "campus_id", null: false
    t.bigint "room_id"
    t.string "status", limit: 30, default: "available", null: false
    t.date "purchase_date"
    t.date "warranty_expiry"
    t.json "maintenance_schedule", default: {}
    t.json "specifications", default: {}
    t.json "booking_rules", default: {}
    t.decimal "purchase_cost", precision: 10, scale: 2
    t.decimal "hourly_rate", precision: 8, scale: 2
    t.text "description"
    t.string "serial_number", limit: 100
    t.boolean "portable", default: false
    t.boolean "requires_training", default: false
    t.integer "max_booking_duration_hours", default: 4
    t.string "condition_rating", limit: 20, default: "good"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id", "code"], name: "idx_unique_equipment_code_per_campus", unique: true
    t.index ["campus_id"], name: "index_equipment_on_campus_id"
    t.index ["equipment_type"], name: "index_equipment_on_equipment_type"
    t.index ["portable"], name: "index_equipment_on_portable"
    t.index ["requires_training"], name: "index_equipment_on_requires_training"
    t.index ["room_id"], name: "idx_equipment_room_assignment"
    t.index ["room_id"], name: "index_equipment_on_room_id"
    t.index ["status"], name: "index_equipment_on_status"
    t.index ["warranty_expiry"], name: "index_equipment_on_warranty_expiry"
  end

  create_table "folders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "color", default: "#3B82F6"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_folders_on_user_id_and_name", unique: true
    t.index ["user_id", "position"], name: "index_folders_on_user_id_and_position"
    t.index ["user_id"], name: "index_folders_on_user_id"
  end

  create_table "grading_rubrics", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "assignment_id"
    t.string "content_type", default: "general"
    t.string "rubric_type", default: "analytic"
    t.text "criteria"
    t.integer "total_points", default: 100
    t.boolean "ai_grading_enabled", default: false
    t.text "ai_prompt_template"
    t.text "description"
    t.bigint "created_by_id", null: false
    t.boolean "active", default: true
    t.bigint "department_id"
    t.string "ai_provider", default: "openai"
    t.integer "usage_count", default: 0
    t.decimal "average_confidence", precision: 5, scale: 3, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_grading_enabled", "active"], name: "idx_rubrics_ai_active"
    t.index ["assignment_id", "active"], name: "idx_rubrics_assignment_active"
    t.index ["assignment_id"], name: "index_grading_rubrics_on_assignment_id"
    t.index ["created_by_id"], name: "index_grading_rubrics_on_created_by_id"
    t.index ["department_id", "content_type"], name: "idx_rubrics_dept_content"
    t.index ["department_id"], name: "index_grading_rubrics_on_department_id"
  end

  create_table "learning_insights", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id"
    t.bigint "schedule_id"
    t.string "insight_type", null: false
    t.decimal "confidence_score", precision: 3, scale: 2, null: false
    t.string "priority", null: false
    t.string "status", default: "active", null: false
    t.text "data"
    t.text "recommendations"
    t.text "metadata"
    t.datetime "dismissed_at"
    t.datetime "implemented_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "title"
    t.text "description"
    t.index ["confidence_score"], name: "index_learning_insights_on_confidence_score"
    t.index ["created_at"], name: "index_learning_insights_on_created_at"
    t.index ["department_id", "status"], name: "index_learning_insights_on_department_id_and_status"
    t.index ["department_id"], name: "index_learning_insights_on_department_id"
    t.index ["insight_type", "priority"], name: "index_learning_insights_on_insight_type_and_priority"
    t.index ["schedule_id"], name: "index_learning_insights_on_schedule_id"
    t.index ["user_id", "status"], name: "index_learning_insights_on_user_id_and_status"
    t.index ["user_id"], name: "index_learning_insights_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.bigint "recipient_id", null: false
    t.text "content"
    t.string "message_type"
    t.integer "thread_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["read_at"], name: "index_messages_on_read_at"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["sender_id", "recipient_id"], name: "index_messages_on_sender_id_and_recipient_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
    t.index ["thread_id"], name: "index_messages_on_thread_id"
  end

  create_table "note_departments", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "department_id", null: false
    t.bigint "shared_by_id", null: false
    t.string "permission_level", default: "view", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_note_departments_on_department_id"
    t.index ["note_id", "department_id"], name: "index_note_departments_on_note_id_and_department_id", unique: true
    t.index ["note_id"], name: "index_note_departments_on_note_id"
    t.index ["shared_by_id"], name: "index_note_departments_on_shared_by_id"
  end

  create_table "note_shares", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "shared_by_id", null: false
    t.bigint "shared_with_id", null: false
    t.string "permission", default: "view", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "shared_with_id"], name: "index_note_shares_on_note_id_and_shared_with_id", unique: true
    t.index ["note_id"], name: "index_note_shares_on_note_id"
    t.index ["shared_by_id"], name: "index_note_shares_on_shared_by_id"
    t.index ["shared_with_id"], name: "index_note_shares_on_shared_with_id"
  end

  create_table "note_tags", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "tag_id"], name: "index_note_tags_on_note_id_and_tag_id", unique: true
    t.index ["note_id"], name: "index_note_tags_on_note_id"
    t.index ["tag_id"], name: "index_note_tags_on_tag_id"
  end

  create_table "notes", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "folder_id"
    t.bigint "department_id"
    t.index ["department_id", "created_at"], name: "index_notes_on_department_id_and_created_at"
    t.index ["department_id"], name: "index_notes_on_department_id"
    t.index ["folder_id"], name: "index_notes_on_folder_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message"
    t.boolean "read", default: false, null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "action_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "performance_metrics", force: :cascade do |t|
    t.string "metric_type"
    t.string "endpoint_path"
    t.decimal "response_time", precision: 10, scale: 3
    t.decimal "memory_usage", precision: 10, scale: 2
    t.decimal "cpu_usage", precision: 5, scale: 2
    t.integer "query_count", default: 0
    t.integer "error_count", default: 0
    t.datetime "recorded_at", precision: nil
    t.json "optimization_suggestions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_path"], name: "index_performance_metrics_on_endpoint_path"
    t.index ["metric_type", "recorded_at"], name: "index_performance_metrics_on_metric_type_and_recorded_at"
    t.index ["recorded_at"], name: "index_performance_metrics_on_recorded_at"
    t.index ["response_time"], name: "index_performance_metrics_on_response_time"
  end

  create_table "plagiarism_checks", force: :cascade do |t|
    t.bigint "submission_id", null: false
    t.decimal "similarity_percentage", precision: 5, scale: 2, default: "0.0"
    t.text "flagged_sections"
    t.text "sources_found"
    t.string "processing_status", default: "pending"
    t.datetime "processed_at"
    t.boolean "requires_review", default: false
    t.string "review_status", default: "pending"
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "instructor_notes"
    t.text "ai_detection_results"
    t.string "escalation_level"
    t.datetime "escalated_at"
    t.boolean "recheck_performed", default: false
    t.decimal "recheck_similarity", precision: 5, scale: 2
    t.datetime "recheck_date"
    t.integer "processing_time_seconds"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escalation_level"], name: "idx_plagiarism_escalation"
    t.index ["processed_at"], name: "idx_plagiarism_processed_at"
    t.index ["processing_status"], name: "idx_plagiarism_status"
    t.index ["requires_review"], name: "idx_plagiarism_review_required"
    t.index ["review_status"], name: "idx_plagiarism_review_status"
    t.index ["reviewed_by_id"], name: "index_plagiarism_checks_on_reviewed_by_id"
    t.index ["similarity_percentage"], name: "idx_plagiarism_similarity"
    t.index ["submission_id"], name: "index_plagiarism_checks_on_submission_id"
  end

  create_table "predictive_analytics", force: :cascade do |t|
    t.string "prediction_type"
    t.string "target_entity_type"
    t.integer "target_entity_id"
    t.decimal "prediction_value"
    t.decimal "confidence_score"
    t.string "model_version"
    t.json "features"
    t.datetime "prediction_date", precision: nil
    t.bigint "campus_id"
    t.bigint "department_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id"], name: "index_predictive_analytics_on_campus_id"
    t.index ["confidence_score"], name: "index_predictive_analytics_on_confidence_score"
    t.index ["department_id"], name: "index_predictive_analytics_on_department_id"
    t.index ["prediction_date"], name: "index_predictive_analytics_on_prediction_date"
    t.index ["prediction_type", "prediction_date"], name: "idx_on_prediction_type_prediction_date_4d0fc151f8"
    t.index ["target_entity_type", "target_entity_id"], name: "idx_on_target_entity_type_target_entity_id_db0fc20b55"
  end

  create_table "program_courses", force: :cascade do |t|
    t.bigint "campus_program_id", null: false
    t.bigint "course_id", null: false
    t.string "course_type", limit: 30, default: "required", null: false
    t.integer "credits", null: false
    t.boolean "required", default: false
    t.integer "semester", default: 1
    t.integer "year", default: 1
    t.text "prerequisites"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_program_id", "course_id"], name: "idx_unique_program_course", unique: true
    t.index ["campus_program_id"], name: "idx_program_courses_on_program"
    t.index ["course_id"], name: "index_program_courses_on_course_id"
    t.index ["course_type"], name: "index_program_courses_on_course_type"
    t.index ["required"], name: "index_program_courses_on_required"
    t.index ["semester", "year"], name: "idx_program_courses_semester_year"
  end

  create_table "program_enrollments", force: :cascade do |t|
    t.bigint "campus_program_id", null: false
    t.bigint "user_id", null: false
    t.string "status", limit: 30, default: "active", null: false
    t.date "enrollment_date", null: false
    t.date "expected_graduation"
    t.date "graduation_date"
    t.date "withdrawal_date"
    t.decimal "final_gpa", precision: 3, scale: 2
    t.text "notes"
    t.integer "credits_completed", default: 0
    t.decimal "current_gpa", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_program_id", "user_id"], name: "idx_unique_program_enrollment", unique: true
    t.index ["campus_program_id"], name: "idx_enrollments_on_program"
    t.index ["enrollment_date"], name: "index_program_enrollments_on_enrollment_date"
    t.index ["graduation_date"], name: "index_program_enrollments_on_graduation_date"
    t.index ["status", "enrollment_date"], name: "idx_enrollments_status_date"
    t.index ["status"], name: "index_program_enrollments_on_status"
    t.index ["user_id"], name: "index_program_enrollments_on_user_id"
  end

  create_table "quiz_attempts", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.bigint "user_id", null: false
    t.decimal "score", precision: 5, scale: 2
    t.integer "correct_answers", default: 0
    t.integer "total_questions", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.json "answers", default: {}
    t.integer "time_taken"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_quiz_attempts_on_completed_at"
    t.index ["quiz_id", "score"], name: "index_quiz_attempts_on_quiz_id_and_score"
    t.index ["quiz_id"], name: "index_quiz_attempts_on_quiz_id"
    t.index ["user_id", "quiz_id"], name: "index_quiz_attempts_on_user_id_and_quiz_id"
    t.index ["user_id"], name: "index_quiz_attempts_on_user_id"
  end

  create_table "quiz_departments", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.bigint "department_id", null: false
    t.bigint "shared_by_id", null: false
    t.string "permission_level", default: "view", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_quiz_departments_on_department_id"
    t.index ["quiz_id", "department_id"], name: "index_quiz_departments_on_quiz_id_and_department_id", unique: true
    t.index ["quiz_id"], name: "index_quiz_departments_on_quiz_id"
    t.index ["shared_by_id"], name: "index_quiz_departments_on_shared_by_id"
  end

  create_table "quiz_questions", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.string "question_type", null: false
    t.text "question_text", null: false
    t.json "options", default: []
    t.text "correct_answer", null: false
    t.text "explanation"
    t.integer "position", null: false
    t.integer "points", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_type"], name: "index_quiz_questions_on_question_type"
    t.index ["quiz_id", "position"], name: "index_quiz_questions_on_quiz_id_and_position"
    t.index ["quiz_id"], name: "index_quiz_questions_on_quiz_id"
  end

  create_table "quizzes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "note_id"
    t.string "title", null: false
    t.text "description"
    t.integer "time_limit", default: 30
    t.string "status", default: "draft"
    t.integer "total_questions", default: 0
    t.string "difficulty", default: "medium"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.index ["department_id", "created_at"], name: "index_quizzes_on_department_id_and_created_at"
    t.index ["department_id"], name: "index_quizzes_on_department_id"
    t.index ["note_id"], name: "index_quizzes_on_note_id"
    t.index ["status"], name: "index_quizzes_on_status"
    t.index ["user_id", "created_at"], name: "index_quizzes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_quizzes_on_user_id"
  end

  create_table "resource_bookings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "bookable_type", null: false
    t.bigint "bookable_id", null: false
    t.string "booking_type", limit: 50, null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", limit: 30, default: "pending", null: false
    t.string "purpose", limit: 255, null: false
    t.text "notes"
    t.string "priority", limit: 20, default: "normal"
    t.json "recurrence", default: {}
    t.string "approval_status", limit: 30, default: "pending"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.text "approval_notes"
    t.decimal "total_cost", precision: 10, scale: 2, default: "0.0"
    t.integer "attendee_count", default: 1
    t.string "contact_email", limit: 255
    t.string "contact_phone", limit: 20
    t.boolean "setup_required", default: false
    t.json "setup_requirements", default: []
    t.datetime "check_in_time"
    t.datetime "check_out_time"
    t.string "booking_reference", limit: 50
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_status"], name: "index_resource_bookings_on_approval_status"
    t.index ["approved_by_id"], name: "index_resource_bookings_on_approved_by_id"
    t.index ["bookable_type", "bookable_id", "start_time", "end_time"], name: "idx_bookings_conflict_check"
    t.index ["bookable_type", "bookable_id"], name: "idx_bookings_on_bookable"
    t.index ["bookable_type", "bookable_id"], name: "index_resource_bookings_on_bookable"
    t.index ["booking_reference"], name: "index_resource_bookings_on_booking_reference", unique: true
    t.index ["start_time", "end_time"], name: "idx_bookings_time_range"
    t.index ["status"], name: "index_resource_bookings_on_status"
    t.index ["user_id"], name: "idx_bookings_by_user"
    t.index ["user_id"], name: "index_resource_bookings_on_user_id"
  end

  create_table "resource_conflicts", force: :cascade do |t|
    t.bigint "primary_booking_id", null: false
    t.bigint "conflicting_booking_id", null: false
    t.string "conflict_type", limit: 50, null: false
    t.string "severity", limit: 20, default: "medium", null: false
    t.string "resolution_status", limit: 30, default: "unresolved", null: false
    t.bigint "resolved_by_id"
    t.text "resolution_notes"
    t.datetime "detected_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "resolved_at"
    t.string "resolution_action", limit: 100
    t.json "conflict_details", default: {}
    t.boolean "auto_resolved", default: false
    t.decimal "resolution_cost", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conflict_type"], name: "index_resource_conflicts_on_conflict_type"
    t.index ["conflicting_booking_id"], name: "index_resource_conflicts_on_conflicting_booking_id"
    t.index ["detected_at"], name: "index_resource_conflicts_on_detected_at"
    t.index ["primary_booking_id", "conflicting_booking_id"], name: "idx_unique_conflict_pair", unique: true
    t.index ["primary_booking_id"], name: "index_resource_conflicts_on_primary_booking_id"
    t.index ["resolution_status"], name: "index_resource_conflicts_on_resolution_status"
    t.index ["resolved_by_id"], name: "index_resource_conflicts_on_resolved_by_id"
    t.index ["severity"], name: "index_resource_conflicts_on_severity"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.bigint "campus_id", null: false
    t.string "building", limit: 100, null: false
    t.integer "floor"
    t.string "room_type", limit: 50, null: false
    t.integer "capacity", default: 1, null: false
    t.json "equipment", default: []
    t.json "amenities", default: []
    t.json "availability_hours", default: {}
    t.json "booking_rules", default: {}
    t.string "status", limit: 30, default: "available", null: false
    t.boolean "requires_approval", default: false
    t.decimal "hourly_rate", precision: 8, scale: 2
    t.text "description"
    t.string "access_level", limit: 30, default: "public"
    t.integer "advance_booking_days", default: 30
    t.integer "max_booking_duration_hours", default: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["building", "floor"], name: "idx_rooms_building_floor"
    t.index ["campus_id", "code"], name: "idx_unique_room_code_per_campus", unique: true
    t.index ["campus_id"], name: "index_rooms_on_campus_id"
    t.index ["capacity"], name: "index_rooms_on_capacity"
    t.index ["requires_approval"], name: "index_rooms_on_requires_approval"
    t.index ["room_type"], name: "index_rooms_on_room_type"
    t.index ["status"], name: "index_rooms_on_status"
  end

  create_table "schedule_participants", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "student"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schedule_id", "user_id"], name: "index_schedule_participants_unique", unique: true
    t.index ["schedule_id"], name: "index_schedule_participants_on_schedule_id"
    t.index ["user_id"], name: "index_schedule_participants_on_user_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "start_time"
    t.datetime "end_time"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "course"
    t.integer "day_of_week"
    t.string "room"
    t.integer "instructor_id"
    t.boolean "recurring", default: true
    t.string "color", default: "#3B82F6"
    t.bigint "department_id"
    t.index ["day_of_week", "start_time"], name: "index_schedules_on_day_of_week_and_start_time"
    t.index ["day_of_week"], name: "index_schedules_on_day_of_week"
    t.index ["department_id", "created_at"], name: "index_schedules_on_department_id_and_created_at"
    t.index ["department_id"], name: "index_schedules_on_department_id"
    t.index ["instructor_id"], name: "index_schedules_on_instructor_id"
    t.index ["user_id"], name: "index_schedules_on_user_id"
  end

  create_table "session_participants", force: :cascade do |t|
    t.bigint "collaborative_session_id", null: false
    t.bigint "user_id", null: false
    t.integer "permission_level", default: 2, null: false
    t.integer "status", default: 0, null: false
    t.datetime "joined_at", precision: nil, null: false
    t.datetime "left_at", precision: nil
    t.datetime "last_seen_at", precision: nil
    t.integer "edits_count", default: 0
    t.integer "comments_count", default: 0
    t.integer "cursor_updates_count", default: 0
    t.json "preferences", default: {}
    t.text "notes"
    t.bigint "invited_by_id"
    t.datetime "invited_at", precision: nil
    t.datetime "invitation_accepted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collaborative_session_id", "status"], name: "idx_session_participants_session_status"
    t.index ["collaborative_session_id", "user_id"], name: "idx_session_participants_unique", unique: true
    t.index ["collaborative_session_id"], name: "index_session_participants_on_collaborative_session_id"
    t.index ["invited_by_id"], name: "index_session_participants_on_invited_by_id"
    t.index ["last_seen_at"], name: "idx_session_participants_last_seen"
    t.index ["user_id", "status", "joined_at"], name: "idx_session_participants_user_activity"
    t.index ["user_id"], name: "index_session_participants_on_user_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "user_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "grade"
    t.text "feedback"
    t.datetime "submitted_at"
    t.datetime "graded_at"
    t.bigint "graded_by_id"
    t.index ["assignment_id"], name: "index_submissions_on_assignment_id"
    t.index ["graded_by_id"], name: "index_submissions_on_graded_by_id"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#10B981"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "template_favorites", force: :cascade do |t|
    t.bigint "content_template_id", null: false
    t.bigint "user_id", null: false
    t.datetime "favorited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_template_id"], name: "index_template_favorites_on_content_template_id"
    t.index ["user_id"], name: "index_template_favorites_on_user_id"
  end

  create_table "template_reviews", force: :cascade do |t|
    t.bigint "content_template_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating"
    t.text "review_text"
    t.integer "helpful_votes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_template_id"], name: "index_template_reviews_on_content_template_id"
    t.index ["user_id"], name: "index_template_reviews_on_user_id"
  end

  create_table "template_usages", force: :cascade do |t|
    t.bigint "content_template_id", null: false
    t.bigint "user_id", null: false
    t.datetime "used_at"
    t.string "context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_template_id"], name: "index_template_usages_on_content_template_id"
    t.index ["user_id"], name: "index_template_usages_on_user_id"
  end

  create_table "universities", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_dashboard_widgets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "widget_type", null: false
    t.string "title"
    t.integer "position", default: 0
    t.integer "grid_x", default: 0
    t.integer "grid_y", default: 0
    t.integer "width", default: 4
    t.integer "height", default: 2
    t.json "configuration", default: {}
    t.boolean "enabled", default: true
    t.integer "refresh_interval", default: 300
    t.datetime "last_refreshed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "enabled"], name: "index_user_dashboard_widgets_on_user_id_and_enabled"
    t.index ["user_id", "position"], name: "index_user_dashboard_widgets_on_user_id_and_position"
    t.index ["user_id", "widget_type"], name: "index_user_dashboard_widgets_on_user_id_and_widget_type"
    t.index ["user_id"], name: "index_user_dashboard_widgets_on_user_id"
  end

  create_table "user_departments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "member"
    t.string "status", default: "active"
    t.datetime "joined_at"
    t.datetime "left_at"
    t.integer "invited_by_id"
    t.text "notes"
    t.index ["department_id"], name: "index_user_departments_on_department_id"
    t.index ["invited_by_id"], name: "index_user_departments_on_invited_by_id"
    t.index ["role"], name: "index_user_departments_on_role"
    t.index ["status"], name: "index_user_departments_on_status"
    t.index ["user_id", "department_id"], name: "index_user_departments_on_user_id_and_department_id", unique: true
    t.index ["user_id"], name: "index_user_departments_on_user_id"
  end

  create_table "user_personalization_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "theme", default: "light"
    t.string "layout_style", default: "standard"
    t.boolean "sidebar_collapsed", default: false
    t.json "dashboard_layout", default: {}
    t.json "ui_preferences", default: {}
    t.json "color_scheme", default: {}
    t.json "accessibility_settings", default: {}
    t.datetime "last_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["theme"], name: "index_user_personalization_preferences_on_theme"
    t.index ["user_id"], name: "index_user_personalization_preferences_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "student", null: false
    t.string "first_name"
    t.string "last_name"
    t.bigint "department_id"
    t.json "push_subscription"
    t.json "notification_preferences"
    t.integer "max_courses", default: 3
    t.jsonb "assigned_courses", default: []
    t.boolean "blacklisted", default: false
    t.datetime "blacklisted_at"
    t.bigint "blacklisted_by_id"
    t.datetime "unblacklisted_at"
    t.bigint "unblacklisted_by_id"
    t.text "blacklist_reason"
    t.string "username"
    t.index ["assigned_courses"], name: "index_users_on_assigned_courses", using: :gin
    t.index ["blacklisted_by_id"], name: "index_users_on_blacklisted_by_id"
    t.index ["department_id", "role"], name: "index_users_on_department_id_and_role"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unblacklisted_by_id"], name: "index_users_on_unblacklisted_by_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_audit_logs", "users", column: "admin_id"
  add_foreign_key "ai_grading_results", "grading_rubrics"
  add_foreign_key "ai_grading_results", "submissions"
  add_foreign_key "ai_grading_results", "users", column: "reviewed_by_id"
  add_foreign_key "ai_usage_logs", "users"
  add_foreign_key "analytics_dashboards", "departments"
  add_foreign_key "analytics_dashboards", "users"
  add_foreign_key "analytics_metrics", "campuses", column: "campus_id"
  add_foreign_key "analytics_metrics", "departments"
  add_foreign_key "analytics_metrics", "users"
  add_foreign_key "analytics_reports", "analytics_dashboards"
  add_foreign_key "analytics_reports", "departments"
  add_foreign_key "analytics_reports", "users"
  add_foreign_key "announcements", "departments"
  add_foreign_key "announcements", "users"
  add_foreign_key "assignment_departments", "assignments"
  add_foreign_key "assignment_departments", "departments"
  add_foreign_key "assignment_departments", "users", column: "shared_by_id"
  add_foreign_key "assignments", "departments"
  add_foreign_key "assignments", "schedules"
  add_foreign_key "assignments", "users"
  add_foreign_key "attendance_lists", "users"
  add_foreign_key "attendance_records", "attendance_lists"
  add_foreign_key "attendance_records", "users"
  add_foreign_key "audit_trails", "users"
  add_foreign_key "business_intelligence_reports", "campuses", column: "campus_id"
  add_foreign_key "business_intelligence_reports", "users", column: "generated_by_id"
  add_foreign_key "campus_programs", "campuses", column: "campus_id"
  add_foreign_key "campus_programs", "departments"
  add_foreign_key "campus_programs", "users", column: "program_director_id"
  add_foreign_key "campuses", "universities"
  add_foreign_key "chat_messages", "users", column: "recipient_id"
  add_foreign_key "chat_messages", "users", column: "sender_id"
  add_foreign_key "collaboration_events", "collaborative_sessions"
  add_foreign_key "collaboration_events", "edit_operations", column: "related_operation_id"
  add_foreign_key "collaboration_events", "users"
  add_foreign_key "collaboration_milestones", "cross_campus_collaborations"
  add_foreign_key "collaboration_participants", "cross_campus_collaborations"
  add_foreign_key "collaboration_participants", "users"
  add_foreign_key "collaboration_resources", "cross_campus_collaborations"
  add_foreign_key "collaborative_sessions", "users", column: "created_by_id"
  add_foreign_key "compliance_assessments", "campuses", column: "campus_id"
  add_foreign_key "compliance_assessments", "compliance_frameworks"
  add_foreign_key "compliance_assessments", "departments"
  add_foreign_key "compliance_assessments", "users", column: "assessor_id"
  add_foreign_key "compliance_reports", "campuses", column: "campus_id"
  add_foreign_key "compliance_reports", "compliance_frameworks"
  add_foreign_key "compliance_reports", "users", column: "generated_by_id"
  add_foreign_key "content_sharing_histories", "departments"
  add_foreign_key "content_sharing_histories", "users", column: "shared_by_id"
  add_foreign_key "content_templates", "content_templates", column: "parent_template_id"
  add_foreign_key "content_templates", "departments"
  add_foreign_key "content_templates", "users", column: "created_by_id"
  add_foreign_key "content_versions", "content_versions", column: "parent_version_id"
  add_foreign_key "content_versions", "users"
  add_foreign_key "content_versions", "users", column: "approved_by_id"
  add_foreign_key "content_versions", "users", column: "published_by_id"
  add_foreign_key "courses", "departments"
  add_foreign_key "cross_campus_collaborations", "campuses", column: "initiating_campus_id"
  add_foreign_key "cross_campus_collaborations", "users", column: "approved_by_id"
  add_foreign_key "cross_campus_collaborations", "users", column: "coordinator_id"
  add_foreign_key "cursor_positions", "collaborative_sessions"
  add_foreign_key "cursor_positions", "users"
  add_foreign_key "dashboard_widgets", "analytics_dashboards"
  add_foreign_key "department_member_histories", "departments"
  add_foreign_key "department_member_histories", "users"
  add_foreign_key "department_member_histories", "users", column: "performed_by_id"
  add_foreign_key "department_settings", "departments"
  add_foreign_key "departments", "campuses", column: "campus_id"
  add_foreign_key "discussion_posts", "discussion_posts", column: "parent_id"
  add_foreign_key "discussion_posts", "discussions"
  add_foreign_key "discussion_posts", "users"
  add_foreign_key "discussions", "users"
  add_foreign_key "edit_operations", "collaborative_sessions"
  add_foreign_key "edit_operations", "edit_operations", column: "parent_operation_id"
  add_foreign_key "edit_operations", "users"
  add_foreign_key "edit_operations", "users", column: "resolved_by_id"
  add_foreign_key "enrollments", "schedules"
  add_foreign_key "enrollments", "users"
  add_foreign_key "equipment", "campuses", column: "campus_id"
  add_foreign_key "equipment", "rooms"
  add_foreign_key "folders", "users"
  add_foreign_key "grading_rubrics", "assignments"
  add_foreign_key "grading_rubrics", "departments"
  add_foreign_key "grading_rubrics", "users", column: "created_by_id"
  add_foreign_key "learning_insights", "departments"
  add_foreign_key "learning_insights", "schedules"
  add_foreign_key "learning_insights", "users"
  add_foreign_key "messages", "users", column: "recipient_id"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "note_departments", "departments"
  add_foreign_key "note_departments", "notes"
  add_foreign_key "note_departments", "users", column: "shared_by_id"
  add_foreign_key "note_shares", "notes"
  add_foreign_key "note_shares", "users", column: "shared_by_id"
  add_foreign_key "note_shares", "users", column: "shared_with_id"
  add_foreign_key "note_tags", "notes"
  add_foreign_key "note_tags", "tags"
  add_foreign_key "notes", "departments"
  add_foreign_key "notes", "folders"
  add_foreign_key "notes", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "plagiarism_checks", "submissions"
  add_foreign_key "plagiarism_checks", "users", column: "reviewed_by_id"
  add_foreign_key "predictive_analytics", "campuses", column: "campus_id"
  add_foreign_key "predictive_analytics", "departments"
  add_foreign_key "program_courses", "campus_programs"
  add_foreign_key "program_courses", "courses"
  add_foreign_key "program_enrollments", "campus_programs"
  add_foreign_key "program_enrollments", "users"
  add_foreign_key "quiz_attempts", "quizzes"
  add_foreign_key "quiz_attempts", "users"
  add_foreign_key "quiz_departments", "departments"
  add_foreign_key "quiz_departments", "quizzes"
  add_foreign_key "quiz_departments", "users", column: "shared_by_id"
  add_foreign_key "quiz_questions", "quizzes"
  add_foreign_key "quizzes", "departments"
  add_foreign_key "quizzes", "notes"
  add_foreign_key "quizzes", "users"
  add_foreign_key "resource_bookings", "users"
  add_foreign_key "resource_bookings", "users", column: "approved_by_id"
  add_foreign_key "resource_conflicts", "resource_bookings", column: "conflicting_booking_id"
  add_foreign_key "resource_conflicts", "resource_bookings", column: "primary_booking_id"
  add_foreign_key "resource_conflicts", "users", column: "resolved_by_id"
  add_foreign_key "rooms", "campuses", column: "campus_id"
  add_foreign_key "schedule_participants", "schedules"
  add_foreign_key "schedule_participants", "users"
  add_foreign_key "schedules", "departments"
  add_foreign_key "schedules", "users"
  add_foreign_key "session_participants", "collaborative_sessions"
  add_foreign_key "session_participants", "users"
  add_foreign_key "session_participants", "users", column: "invited_by_id"
  add_foreign_key "submissions", "assignments"
  add_foreign_key "submissions", "users"
  add_foreign_key "submissions", "users", column: "graded_by_id"
  add_foreign_key "template_favorites", "content_templates"
  add_foreign_key "template_favorites", "users"
  add_foreign_key "template_reviews", "content_templates"
  add_foreign_key "template_reviews", "users"
  add_foreign_key "template_usages", "content_templates"
  add_foreign_key "template_usages", "users"
  add_foreign_key "user_dashboard_widgets", "users"
  add_foreign_key "user_departments", "departments"
  add_foreign_key "user_departments", "users"
  add_foreign_key "user_departments", "users", column: "invited_by_id"
  add_foreign_key "user_personalization_preferences", "users"
  add_foreign_key "users", "departments"
  add_foreign_key "users", "users", column: "blacklisted_by_id"
  add_foreign_key "users", "users", column: "unblacklisted_by_id"
end
