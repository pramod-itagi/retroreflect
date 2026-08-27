require "rails_helper"

RSpec.describe Team, type: :model do
  it "requires unique names among active teams and allows reuse after archive" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator, name: "Platform")

    duplicate = Team.new(name: "Platform", created_by: facilitator)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present

    Teams::Archive.new(team).call
    replacement = Team.create!(name: "Platform", created_by: facilitator)
    expect(replacement).to be_persisted
    expect(Team.where(name: "Platform").count).to eq(2)
  end
end
