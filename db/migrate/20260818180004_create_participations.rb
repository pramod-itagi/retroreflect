class CreateParticipations < ActiveRecord::Migration[7.1]
  def change
    create_table :participations do |t|
      t.references :retrospective, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.string :invitation_token_digest, limit: 64
      t.datetime :invited_at
      t.datetime :accessed_at
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :participations, [:retrospective_id, :user_id], unique: true
    add_index :participations, :invitation_token_digest, unique: true
    add_index :participations, [:retrospective_id, :submitted_at]
  end
end
