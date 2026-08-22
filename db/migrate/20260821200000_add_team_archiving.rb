class AddTeamArchiving < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :archived_at, :datetime
    add_index :teams, :archived_at

    add_column :memberships, :deactivated_at, :datetime
    add_index :memberships, :deactivated_at
  end
end
