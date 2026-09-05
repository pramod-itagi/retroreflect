class AddSessionVersionToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :session_version, :integer, null: false, default: 1
  end
end
