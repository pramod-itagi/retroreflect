class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      t.references :team, null: false, foreign_key: { on_delete: :restrict }
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.string :role, null: false, limit: 20

      t.timestamps
    end

    add_index :memberships, [:team_id, :user_id], unique: true
    add_index :memberships, [:team_id, :role]
  end
end
