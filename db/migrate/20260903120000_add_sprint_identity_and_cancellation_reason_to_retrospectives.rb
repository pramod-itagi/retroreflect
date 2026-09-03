class AddSprintIdentityAndCancellationReasonToRetrospectives < ActiveRecord::Migration[7.1]
  def change
    add_column :retrospectives, :sprint_number, :integer
    add_column :retrospectives, :sprint_year, :integer
    add_column :retrospectives, :cancellation_reason, :text
    add_index :retrospectives, [:team_id, :sprint_number],
              unique: true,
              name: "index_retrospectives_on_team_id_and_sprint_number"
  end
end
