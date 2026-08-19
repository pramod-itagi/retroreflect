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
  end

  it "treats discarded users as inactive" do
    user = create_user(name: "Ada", email: "ada@example.com")
    user.discard!

    expect(user).to be_discarded
    expect(User.active.find_by(id: user.id)).to be_nil
    expect(user.reload.display_name).to eq("Unknown User")
  end
end
