class DepartmentMemberImportService
  attr_reader :department, :csv_file, :imported_by, :errors, :successes
  
  def initialize(department, csv_file, imported_by)
    @department = department
    @csv_file = csv_file
    @imported_by = imported_by
    @errors = []
    @successes = []
  end
  
  def import
    require 'csv'
    
    csv_data = csv_file.respond_to?(:read) ? csv_file.read : File.read(csv_file)
    rows = CSV.parse(csv_data, headers: true)
    
    if rows.headers.nil? || !valid_headers?(rows.headers)
      @errors << "Invalid CSV format. Required headers: email, role (optional), notes (optional)"
      return false
    end
    
    rows.each_with_index do |row, index|
      process_row(row, index + 2) # +2 because of header row and 0-index
    end
    
    # Log the import
    if @successes.any?
      users = @successes.map { |s| s[:user] }
      DepartmentMemberHistory.log_import(users, @department, @imported_by, {
        total: rows.size,
        successful: @successes.size,
        failed: @errors.size
      })
    end
    
    @errors.empty?
  end
  
  def summary
    {
      total: @successes.size + @errors.size,
      successful: @successes.size,
      failed: @errors.size,
      errors: @errors,
      successes: @successes
    }
  end
  
  private
  
  def valid_headers?(headers)
    headers.map(&:downcase).include?('email')
  end
  
  def process_row(row, row_number)
    email = row['email']&.strip&.downcase
    role = row['role']&.strip&.downcase || 'member'
    notes = row['notes']&.strip
    
    if email.blank?
      @errors << { row: row_number, error: "Email is required" }
      return
    end
    
    user = User.find_by(email: email)
    if user.nil?
      @errors << { row: row_number, email: email, error: "User not found" }
      return
    end
    
    # Check if user is already in department
    if user.department_id == @department.id
      @errors << { row: row_number, email: email, error: "User already assigned to this department" }
      return
    end
    
    existing_membership = @department.user_departments.find_by(user: user)
    if existing_membership
      if existing_membership.active?
        @errors << { row: row_number, email: email, error: "User already has active membership" }
        return
      else
        # Reactivate existing membership
        existing_membership.activate!
        existing_membership.update(role: role, notes: notes, invited_by: @imported_by)
        @successes << { row: row_number, email: email, user: user, action: 'reactivated' }
        return
      end
    end
    
    # Validate role for user_departments (must be tutor/teacher/admin)
    unless user.has_role?('tutor', 'teacher', 'admin', 'super_admin')
      # For students, update their department_id instead
      if user.department_id.nil?
        user.update!(department_id: @department.id)
        @successes << { row: row_number, email: email, user: user, action: 'assigned' }
      else
        @errors << { row: row_number, email: email, error: "Student already assigned to another department. Use transfer instead." }
      end
      return
    end
    
    # Create new membership for tutors/teachers/admins
    membership = @department.user_departments.build(
      user: user,
      role: role,
      status: 'active',
      joined_at: Time.current,
      invited_by: @imported_by,
      notes: notes
    )
    
    if membership.save
      @successes << { row: row_number, email: email, user: user, action: 'added' }
    else
      @errors << { row: row_number, email: email, error: membership.errors.full_messages.join(', ') }
    end
  rescue => e
    @errors << { row: row_number, email: email, error: e.message }
  end
end
