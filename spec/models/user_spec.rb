require "rails_helper"

RSpec.describe User, type: :model do
  it "requires a unique email, a name, and a password of at least 8 characters" do
    create_user(name: "Ada", email: "ada@example.com")

    duplicate = User.new(name: "Ada Two", email: "ADA@example.com", password: "password123")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present

    short = User.new(name: "Bee", email: "bee@example.com", password: "short")
    expect(short).not_to be_valid
    expect(short.errors[:password]).to be_present

    nameless = User.new(name: "", email: "cee@example.com", password: "password123")
    expect(nameless).not_to be_valid
    expect(nameless.errors[:name]).to be_present

    missing_confirmation = User.new(name: "Dee", email: "dee@example.com", password: "password123")
    expect(missing_confirmation).not_to be_valid
    expect(missing_confirmation.errors[:password_confirmation]).to be_present
  end

  it "treats system admin as independent from team facilitator membership" do
    admin = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: jordan)

    expect(admin).to be_system_admin
    expect(admin).not_to be_facilitator
    expect(jordan).not_to be_system_admin
    expect(jordan).to be_facilitator
    expect(team.memberships.find_by(user: admin)).to be_nil
  end

  it "stores a password digest and unique email index, not a plaintext password" do
    user = create_user(name: "Ada", email: "ada@example.com")

    expect(User.column_names).to include("password_digest")
    expect(User.column_names).not_to include("password", "password_confirmation")
    expect(user.password_digest).to be_present
    expect(user.password_digest).not_to eq("password123")
    expect(user.authenticate("password123")).to eq(user)

    email_index = ActiveRecord::Base.connection.indexes(:users).find { |index| index.columns == ["email"] }
    expect(email_index).to be_present
    expect(email_index.unique).to be true
  end

  it "treats discarded users as inactive" do
    user = create_user(name: "Ada", email: "ada@example.com")
    user.discard!

    expect(user).to be_discarded
    expect(User.active.find_by(id: user.id)).to be_nil
    expect(user.reload.display_name).to eq("Unknown User")
  end
end
