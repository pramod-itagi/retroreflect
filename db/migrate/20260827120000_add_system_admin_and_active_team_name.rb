class AddSystemAdminAndActiveTeamName < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :system_admin, :boolean, null: false, default: false
    add_index :users, :system_admin

    execute <<~SQL
      ALTER TABLE teams
      ADD COLUMN active_name VARCHAR(100)
        GENERATED ALWAYS AS (
          CASE
            WHEN archived_at IS NULL THEN name
            ELSE NULL
          END
        ) STORED,
      ADD UNIQUE INDEX index_teams_on_active_name (active_name)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE teams
      DROP INDEX index_teams_on_active_name,
      DROP COLUMN active_name
    SQL

    remove_index :users, :system_admin
    remove_column :users, :system_admin
  end
end
