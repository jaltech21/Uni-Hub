class CreateQuizzes < ActiveRecord::Migration[8.0]
  def change
    create_table :quizzes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :note, null: true, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :time_limit, default: 30 # minutes
      t.string :status, default: 'draft' # draft, published
      t.integer :total_questions, default: 0
      t.string :difficulty, default: 'medium' # easy, medium, hard

      t.timestamps
    end
    
    add_index :quizzes, :status
    add_index :quizzes, [:user_id, :created_at]
  end
end
