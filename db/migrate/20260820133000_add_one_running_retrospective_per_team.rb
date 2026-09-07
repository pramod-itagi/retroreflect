class AddOneRunningRetrospectivePerTeam < ActiveRecord::Migration[7.1]
  def change
    add_index :retrospectives, :team_id,
              unique: true,
              where: "status IN ('draft', 'collecting', 'discussing')",
              name: "index_retrospectives_one_running_per_team"
  end
end
