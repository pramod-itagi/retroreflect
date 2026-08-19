class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false, limit: 100
      t.datetime :confirmed_at
      t.string :confirmation_token_digest, limit: 64
      t.datetime :confirmation_sent_at
      t.string :password_reset_token_digest, limit: 64
      t.datetime :password_reset_sent_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :confirmation_token_digest, unique: true
    add_index :users, :password_reset_token_digest, unique: true
    add_index :users, :discarded_at
  end
end
