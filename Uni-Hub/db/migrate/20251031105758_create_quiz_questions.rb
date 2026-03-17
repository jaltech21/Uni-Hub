class CreateQuizQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_questions do |t|
      t.references :quiz, null: false, foreign_key: true
      t.string :question_type, null: false # multiple_choice, true_false, short_answer
      t.text :question_text, null: false
      t.json :options, default: [] # For multiple choice options
      t.text :correct_answer, null: false
      t.text :explanation # Optional explanation for the answer
      t.integer :position, null: false # Order of question in quiz
      t.integer :points, default: 1 # Points for this question

      t.timestamps
    end
    
    add_index :quiz_questions, [:quiz_id, :position]
    add_index :quiz_questions, :question_type
  end
end
