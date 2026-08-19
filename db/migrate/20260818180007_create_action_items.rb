class CreateActionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :action_items do |t|
      t.references :team, null: false, foreign_key: { on_delete: :restrict }
      t.references :retrospective, foreign_key: { on_delete: :nullify }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :owner, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :title, null: false
      t.text :description
      t.date :due_on, null: false
      t.string :status, null: false, limit: 32, default: "open"
      t.datetime :completed_at
      t.references :completed_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :cancelled_at
      t.references :cancelled_by, foreign_key: { to_table: :users, on_delete: :restrict }

      t.timestamps
    end

    add_index :action_items, [:team_id, :status]
    add_index :action_items, :due_on
  end
end
