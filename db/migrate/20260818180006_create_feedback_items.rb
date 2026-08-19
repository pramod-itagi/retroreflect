class CreateFeedbackItems < ActiveRecord::Migration[7.1]
  def change
    create_table :feedback_items, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.references :retrospective, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false, limit: 32
      t.text :body, null: false
      t.integer :reveal_position, null: false

      t.timestamps
    end

    add_index :feedback_items, [:retrospective_id, :reveal_position], unique: true
    add_index :feedback_items, [:retrospective_id, :category]
  end
end
