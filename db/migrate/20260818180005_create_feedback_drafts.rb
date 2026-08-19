class CreateFeedbackDrafts < ActiveRecord::Migration[7.1]
  def change
    create_table :feedback_drafts do |t|
      t.references :retrospective, null: false, foreign_key: { on_delete: :cascade }
      t.references :participation, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false, limit: 32
      t.text :body, null: false

      t.timestamps
    end
  end
end
