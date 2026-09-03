class AddStatusEventsToActionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :action_item_status_events do |t|
      t.references :action_item, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :previous_status, null: false, limit: 32
      t.string :new_status, null: false, limit: 32
      t.text :comment, null: false
      t.timestamps
    end

    add_index :action_item_status_events, [:action_item_id, :created_at],
              name: "index_action_item_status_events_on_item_and_created_at"
  end
end
