class AddOneRunningRetrospectivePerTeam < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      ALTER TABLE retrospectives
      ADD COLUMN running_team_id BIGINT
        GENERATED ALWAYS AS (
          CASE
            WHEN status IN ('draft', 'collecting', 'discussing') THEN team_id
            ELSE NULL
          END
        ) STORED,
      ADD UNIQUE INDEX index_retrospectives_one_running_per_team (running_team_id)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE retrospectives
      DROP INDEX index_retrospectives_one_running_per_team,
      DROP COLUMN running_team_id
    SQL
  end
end
