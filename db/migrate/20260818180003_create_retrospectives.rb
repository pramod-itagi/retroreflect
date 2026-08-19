class CreateRetrospectives < ActiveRecord::Migration[7.1]
  def change
    create_table :retrospectives do |t|
      t.references :team, null: false, foreign_key: { on_delete: :restrict }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :title, null: false
      t.string :sprint_label, limit: 100
      t.datetime :scheduled_at
      t.string :status, null: false, limit: 20, default: "draft"
      t.datetime :collecting_started_at
      t.datetime :revealed_at
      t.datetime :closed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :retrospectives, [:team_id, :status]
  end
end
