# config/routes.rb
Rails.application.routes.draw do
  # ActionCable for real-time communication
  mount ActionCable.server => '/cable'
  
  # Username and Email availability checks
  get 'check_username', to: 'users#check_username'
  get 'check_email', to: 'users#check_email'
  
  # Global Search System
  get 'search', to: 'search#index', as: :search
  get 'search/results', to: 'search#results', as: :search_results
  get 'search/suggestions', to: 'search#suggestions', as: :search_suggestions
  # Real-time Communication System
  resources :messages, only: [:index, :show, :create, :destroy] do
    collection do
      get :conversations
      post :mark_as_read
      get :search_users
    end
  end
  
  # Push Notifications
  resources :push_notifications, only: [:index] do
    collection do
      post :subscribe
      delete :unsubscribe
      get :status
      patch :update_preferences
      post :test
    end
  end
  
  resources :discussions do
    member do
      patch :close
      patch :reopen  
      patch :pin
      patch :unpin
      patch :archive
    end
    collection do
      get :search
      post :create_post
      post :create_reply
    end
  end
  # Active Admin routes - Disabled in favor of custom admin interface
  # devise_for :admin_users, ActiveAdmin::Devise.config
  # ActiveAdmin.routes(self)

  # Admin authentication routes (separate from regular users)
  devise_scope :user do
    # Admin login/logout
    get '/admin/login', to: 'admin/sessions#new', as: :new_admin_session
    post '/admin/login', to: 'admin/sessions#create', as: :admin_session
    delete '/admin/logout', to: 'admin/sessions#destroy', as: :destroy_admin_session
  end

  # User authentication routes (for students and teachers)
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }
  
  # Root route for authenticated users
  authenticated :user do
    root to: 'pages#dashboard', as: :authenticated_root
  end
  
  # Dashboard routes
  get 'dashboard', to: 'pages#dashboard'
  post 'dashboard/update_layout', to: 'dashboard#update_layout'
  post 'dashboard/add_widget', to: 'dashboard#add_widget'
  delete 'dashboard/remove_widget/:id', to: 'dashboard#remove_widget', as: 'remove_dashboard_widget'
  patch 'dashboard/configure_widget/:id', to: 'dashboard#configure_widget', as: 'configure_dashboard_widget'
  post 'dashboard/refresh_widget/:id', to: 'dashboard#refresh_widget', as: 'refresh_dashboard_widget'
  post 'dashboard/reset', to: 'dashboard#reset_dashboard', as: 'reset_dashboard'
  post 'dashboard/widgets/ai_recommendations/refresh', to: 'dashboard#refresh_ai_recommendations', as: 'refresh_ai_recommendations'
  
  # Personalization routes
  resource :personalization_preferences, only: [:show, :update] do
    member do
      post :reset_theme
      post :apply_preset
    end
  end

  # Application Routes (Full RESTful resources, except where noted)
  resources :notes do
    member do
      post :share
      get 'export', defaults: { format: 'md' }
      post :auto_save
    end
    
    # Collaboration
    post :collaborate, to: 'collaboration_sessions#create'
    
    # Version history
    resources :versions, controller: 'version_history', only: [:index, :show, :destroy] do
      member do
        post :restore
        get :download
      end
      collection do
        get :compare
        post :create_branch
        post :publish_draft
        get :changes_summary
      end
    end
  end
  resources :folders, only: [:index, :create, :update, :destroy]
  resources :notifications, only: [:index, :destroy] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
      get :unread_count
      get :recent
    end
  end
  resources :summarizations, only: [:new, :create] do
    collection do
      post :save_to_note
    end
  end
  resources :quizzes do
    member do
      get :take
      post :submit_quiz
      get :results
      patch :publish
    end
    collection do
      get :generate
      post :generate_from_note
    end
    
    # Collaboration
    post :collaborate, to: 'collaboration_sessions#create'
    
    # Version history
    resources :versions, controller: 'version_history', only: [:index, :show, :destroy] do
      member do
        post :restore
        get :download
      end
      collection do
        get :compare
        post :create_branch
        post :publish_draft
        get :changes_summary
      end
    end
  end
  
  # Schedules: Teachers can only view/edit (limited fields), not create/destroy
  resources :schedules, only: [:index, :show, :edit, :update] do
    collection do
      post :check_conflicts_ajax
      get :browse
    end
    member do
      post :enroll
      delete :unenroll
    end
  end

  # Departments Routes (Full RESTful resources, except where noted)
  
  # Enrollments
  resources :enrollments, only: [:index, :new, :create, :destroy] do
    collection do
      get 'capacity/:schedule_id', to: 'enrollments#capacity', as: :capacity
    end
  end
  
  resources :assignments do 
    # Submissions: Nested under assignments
    resources :submissions, only: [:index, :new, :create, :show, :edit, :update]
    
    # Collaboration
    post :collaborate, to: 'collaboration_sessions#create'
    
    # Version history
    resources :versions, controller: 'version_history', only: [:index, :show, :destroy] do
      member do
        post :restore
        get :download
      end
      collection do
        get :compare
        post :create_branch
        post :publish_draft
        get :changes_summary
      end
    end
  end
  
  # Collaboration Sessions
  resources :collaboration_sessions do
    member do
      post :join
      delete :leave
      patch :pause
      patch :resume
      post :invite
      get :participants
      get :history
      patch 'participants/:user_id', to: 'collaboration_sessions#update_participant', as: :update_participant
      delete 'participants/:user_id', to: 'collaboration_sessions#remove_participant', as: :remove_participant
    end
  end

  # Attendance Lists: Now defines all 7 RESTful actions to support full CRUD
  resources :attendance_lists do 
    member do
      # ADD THIS LINE: Dedicated route for refreshing the code
      get :refresh_code 
    end
    # Attendance Records: Nested under lists, index (for marking) and create (for saving status)
    resources :attendance_records, only: [:index, :create] 
  end
  
  # Admin Panel namespace (custom admin interface)
  namespace :admin_panel, path: 'admin' do
    resources :ai_analytics, only: [:index]
    
    # Course Management (Admin creates courses)
    resources :courses do
      member do
        patch :toggle_active
      end
    end
    
    # Schedule Management (Admin creates schedules and assigns teachers)
    resources :schedules do
      member do
        post :approve
        post :cancel
      end
    end
  end
  
  # Legacy admin routes (keep existing admin namespace for other controllers)
  namespace :admin do
    # Admin must be authenticated to access these routes
    root to: 'dashboard#index', as: :root
    get 'dashboard', to: 'dashboard#index'
    
    resources :departments do
      member do
        patch :toggle_active
      end
    end
    
    resources :user_management do
      member do
        patch :assign_department
        patch :change_role
        patch :blacklist
        patch :unblacklist
      end
    end
    
    # Multi-Campus Institution Management
    resources :campuses do
      member do
        get :statistics
        get :collaboration_network
        get :performance_metrics
        get :operating_hours
      end
      
      # Campus Programs Management
      resources :campus_programs, path: 'programs' do
        member do
          post :enroll_student
          delete :withdraw_student
          patch :graduate_student
          get :statistics
          get :manage_courses
          post :manage_courses
          delete :remove_course
        end
      end
    end
    
    # Cross-Campus Collaboration Management
    resources :cross_campus_collaborations, path: 'collaborations' do
      member do
        post :add_milestone
        patch :complete_milestone
        post :add_participant
        delete :remove_participant
        post :add_resource
        post :add_expense
      end
      collection do
        get :collaboration_network
        get :dashboard_data
      end
    end
    
    # Course Management
    resources :courses do
      member do
        patch :toggle_active
      end
    end
    
    # Resource Management System
    resources :rooms do
      member do
        get :availability
        get :bookings
        patch :toggle_status
      end
      collection do
        get :available_rooms
        get :search_rooms
      end
    end
    
    resources :equipment do
      member do
        get :availability
        get :bookings
        patch :toggle_status
        post :schedule_maintenance
        post :complete_maintenance
      end
      collection do
        get :available_equipment
        get :maintenance_due
      end
    end
    
    resources :resource_bookings, path: 'bookings' do
      member do
        post :approve
        post :reject
        post :cancel
        post :check_in
        post :check_out
      end
      collection do
        get :check_availability
        get :calendar_data
        post :bulk_action
        get :statistics
      end
    end
    
    resources :resource_conflicts, path: 'conflicts', only: [:index, :show] do
      member do
        post :resolve
        post :auto_resolve
        post :escalate
      end
      collection do
        get :unresolved
        post :resolve_all
      end
    end
  end

  # Announcements
  resources :announcements do
    member do
      patch :publish
      patch :unpublish
      patch :toggle_pin
    end
  end
  
  # Content Sharing
  resources :content_sharing, only: [:show, :create, :destroy] do
    collection do
      patch :update_permission
    end
  end
  
  # Department routes
  resources :departments, only: [] do
    member do
      get :dashboard, to: 'departments/dashboard#show'
    end
    
    # Department Settings (singular resource)
    resource :settings, only: [:show, :edit, :update], controller: 'departments/settings' do
      member do
        post :add_template
        delete :remove_template
        get :preview
      end
    end
    
    # Department Members
    resources :members, only: [:index, :show, :new, :create, :edit, :update, :destroy], controller: 'departments/members' do
      collection do
        post :import
        post :bulk_add
        post :bulk_remove
        get :history
        get :export
      end
    end
    
    # Department Reports
    resources :reports, only: [:index], controller: 'departments/reports' do
      collection do
        get :member_stats
        get :activity_summary
        get :content_report
        get :export_all
        # CSV exports
        get :send_member_stats_csv
        get :send_activity_summary_csv
        get :send_content_report_csv
        # PDF exports
        get :send_member_stats_pdf
        get :send_activity_summary_pdf
        get :send_content_report_pdf
        get :send_comprehensive_pdf
        # Excel exports
        get :send_member_stats_excel
        get :send_activity_summary_excel
        get :send_content_report_excel
        get :send_comprehensive_excel
      end
    end
    
    # Department Activity Feed
    resources :activity, only: [:index], controller: 'departments/activity' do
      collection do
        get :filter
        get :load_more
      end
    end
  end
  
  # Static pages and health check
  # Week 8: Advanced Analytics & Intelligence System Routes
  resources :advanced_analytics, path: 'analytics' do
    collection do
      get :dashboard
      get :metrics
      get :predictions
      get :student_analytics
      get :department_analytics
      get :campus_analytics
      get :performance_monitoring
      get :anomaly_detection
      post :export_data
      get :widget_data
    end
  end
  
  # Data Mining & Pattern Recognition
  resources :data_mining, path: 'data_mining' do
    collection do
      get :pattern_discovery
      get :association_analysis
      get :clustering_analysis
      get :anomaly_detection
      get :trend_analysis
      get :sentiment_analysis
      get :network_analysis
      post :run_algorithm
      get :export_patterns
    end
  end
  
  # Advanced Search & Recommendation Engine
  resources :advanced_search, path: 'search' do
    collection do
      get :search
      get :recommendations
      get :auto_complete
      get :trending
      get :personalization
      post :feedback
      get :similar_items
      get :search_analytics
    end
  end
  
  # Integration Hub for Third-Party Systems
  resources :integration_hub, path: 'integrations' do
    collection do
      get :lms_integrations
      get :sis_integrations
      get :communication_integrations
      get :analytics_integrations
      post :configure_integration
      post :test_integration
      post :sync_data
      get :sync_status
      get :api_keys
      get :webhooks
      post :create_webhook
      get :integration_logs
      get :data_mapping
      patch :update_mapping
    end
  end
  
  resources :business_intelligence_reports, path: 'bi_reports' do
    member do
      post :publish
      get :export
    end
    collection do
      get :dashboard
      post :generate_automated
      get :insights_analysis
      get :performance_benchmarks
      get :strategic_planning
      post :schedule_report
    end
  end
  
  resources :predictive_analytics do
    member do
      post :run_prediction
      post :update_model
    end
    collection do
      get :dashboard
      post :batch_predictions
      get :student_risk_assessment
      get :academic_forecasting
      get :resource_optimization
      get :model_comparison
      get :export_predictions
    end
  end
  
  resources :performance_metrics do
    member do
      post :analyze
    end
    collection do
      get :dashboard
      get :real_time_monitoring
      get :optimization_recommendations
      get :capacity_planning
      get :historical_analysis
      get :export_metrics
      post :bulk_analysis
    end
  end
  
  # Legacy analytics routes (for backward compatibility)
  resources :analytics_dashboards do
    member do
      get :widget_data
      patch :update_layout
      post :add_widget
      delete :remove_widget
      get :export_dashboard
      get :insights
      patch :toggle_active
      post :duplicate
    end
    collection do
      get :templates
      post :create_from_template
    end
  end
  
  resources :analytics_reports do
    member do
      post :generate
      post :regenerate
      get :export
      get :status
      post :cancel_generation
    end
    collection do
      post :schedule
      get :preview
      get :templates
      post :create_from_template
    end
  end
  
  # Learning Insights routes
  resources :learning_insights, only: [:index, :show] do
    member do
      patch :dismiss
      patch :implement
      patch :archive
      patch :quick_dismiss
      patch :quick_implement
      patch :update_priority
      post :add_note
      post :refresh_insight
    end
    collection do
      post :generate_insights
      post :bulk_action
      get :analytics
      get :predictive_dashboard
      get :export_insights
      get :intervention_tracker
    end
  end
  
  # Student profile insights
  get 'students/:student_id/insights', to: 'learning_insights#student_profile', as: :student_insights
  
  # Content Templates System
  resources :content_templates do
    member do
      post :duplicate
      post :favorite
      delete :unfavorite
      post :review
      post :use_template, as: :use
    end
    collection do
      get :marketplace
      get :search
      get :my_templates
      get :favorites
    end
  end

  # AI Grading and Plagiarism Management System
  namespace :instructors do
    resources :departments, only: [] do
      # AI Grading Dashboard
      get :ai_grading_dashboard, to: 'ai_grading#dashboard', as: :ai_grading_dashboard
      get 'ai_grading/accuracy_report', to: 'ai_grading#accuracy_report', as: :ai_grading_accuracy_report
      
      resources :assignments, only: [] do
        # AI Grading for specific assignments
        get :ai_grading, to: 'ai_grading#show', as: :ai_grading
        post :grade_assignment, to: 'ai_grading#grade_assignment', as: :grade_assignment
        get :grading_progress, to: 'ai_grading#grading_progress', as: :grading_progress
        
        # AI Grading Results Review
        resources :ai_grading_results, path: 'grading_results', controller: 'ai_grading', only: [] do
          member do
            get :review, to: 'ai_grading#review_results', as: :review
            patch :approve, to: 'ai_grading#approve_grade', as: :approve
            patch :reject, to: 'ai_grading#reject_grade', as: :reject
          end
        end
        
        # Batch AI Grading Actions
        post 'ai_grading/batch_review', to: 'ai_grading#batch_review', as: :batch_review_ai_grading
        get 'ai_grading/export', to: 'ai_grading#export_results', as: :export_ai_grading_results
        
        # Plagiarism Management for specific assignments
        get :plagiarism, to: 'plagiarism#show', as: :plagiarism
        post :check_plagiarism, to: 'plagiarism#check_assignment', as: :check_plagiarism
        get :plagiarism_progress, to: 'plagiarism#check_progress', as: :plagiarism_progress
      end
      
      # Department-wide Plagiarism Dashboard
      get :plagiarism_dashboard, to: 'plagiarism#dashboard', as: :plagiarism_dashboard
      post :bulk_plagiarism_check, to: 'plagiarism#bulk_check', as: :bulk_plagiarism_check
      
      # Plagiarism Case Management
      resources :plagiarism_checks, path: 'plagiarism_cases', controller: 'plagiarism', only: [] do
        member do
          get :review, to: 'plagiarism#review', as: :review
          patch :approve, to: 'plagiarism#approve', as: :approve
          patch :flag_for_investigation, to: 'plagiarism#flag_for_investigation', as: :flag_for_investigation
          patch :dismiss, to: 'plagiarism#dismiss', as: :dismiss
        end
      end
      
      # Plagiarism Reports and Analytics
      get 'plagiarism/export', to: 'plagiarism#export_report', as: :export_plagiarism_report
      get 'plagiarism/trends', to: 'plagiarism#similarity_trends', as: :plagiarism_trends
      get 'plagiarism/student_report/:student_id', to: 'plagiarism#student_report', as: :student_plagiarism_report
    end
  end

  # Compliance & Reporting routes
  resources :compliance_frameworks do
    member do
      post :generate_report
      post :schedule_assessment
      get :export_framework
    end
    collection do
      get :compliance_dashboard
    end
    resources :compliance_assessments do
      member do
        patch :complete
        patch :approve
        patch :reject
        get :export_assessment
      end
      collection do
        get :dashboard
      end
    end
    resources :compliance_reports do
      member do
        patch :publish
        get :export
      end
      collection do
        post :generate_automated
        get :dashboard
      end
    end
  end

  # Department switcher route (used by UI to change current department in session)
  post 'department/switch', to: 'departments#switch', as: :switch_department

  get "pages/home"
  get "pages/features"
  get "pages/pricing"
  get "pages/about"
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/") for unauthenticated users
  root "pages#home"
end