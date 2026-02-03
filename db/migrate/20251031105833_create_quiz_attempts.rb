class CreateQuizAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_attempts do |t|
      t.references :quiz, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :score, precision: 5, scale: 2 # Percentage score
      t.integer :correct_answers, default: 0
      t.integer :total_questions, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.json :answers, default: {} # { question_id: user_answer }
      t.integer :time_taken # seconds

      t.timestamps
    end
    
    add_index :quiz_attempts, [:user_id, :quiz_id]
    add_index :quiz_attempts, :completed_at
    add_index :quiz_attempts, [:quiz_id, :score]
  end
end
