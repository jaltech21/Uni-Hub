class EnhanceAssignmentsAndSubmissions < ActiveRecord::Migration[8.0]
  def change
    # Add fields to assignments table
    add_column :assignments, :points, :integer, default: 100
    add_column :assignments, :category, :string, default: 'homework' # homework, project, quiz, exam
    add_column :assignments, :grading_criteria, :text
    add_column :assignments, :allow_resubmission, :boolean, default: false
    add_column :assignments, :course_name, :string

    # Add fields to submissions table
    add_column :submissions, :grade, :integer
    add_column :submissions, :feedback, :text
    add_column :submissions, :submitted_at, :datetime
    add_column :submissions, :graded_at, :datetime
    add_column :submissions, :graded_by_id, :bigint

    # Add index for graded_by foreign key
    add_index :submissions, :graded_by_id
    
    # Add foreign key constraint for graded_by (references users table)
    add_foreign_key :submissions, :users, column: :graded_by_id
  end
end
