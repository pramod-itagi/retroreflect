class AddSystemAdminAndActiveTeamName < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :system_admin, :boolean, null: false, default: false
    add_index :users, :system_admin

    add_index :teams, "LOWER(name)",
              unique: true,
              where: "archived_at IS NULL",
              name: "index_teams_on_active_name"
  end
end
