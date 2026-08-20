require "rails_helper"

RSpec.describe Retrospective, type: :model do
  def build_retro(team, facilitator, title:)
    team.retrospectives.build(title: title, created_by: facilitator)
  end

  it "rejects a second running retrospective for the same team" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    first = team.retrospectives.create!(title: "First", created_by: facilitator)

    second = build_retro(team, facilitator, title: "Second")
    expect(second).not_to be_valid
    expect(second.errors[:base]).to include(described_class::ONE_ACTIVE_MESSAGE)

    first.update!(status: :collecting, collecting_started_at: Time.current)
    expect(build_retro(team, facilitator, title: "While collecting")).not_to be_valid

    first.update!(status: :discussing, revealed_at: Time.current)
    expect(build_retro(team, facilitator, title: "While discussing")).not_to be_valid
  end

  it "allows a new retrospective after the previous one is closed or cancelled" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    previous = team.retrospectives.create!(title: "First", created_by: facilitator)

    previous.update!(status: :cancelled, cancelled_at: Time.current)
    expect(build_retro(team, facilitator, title: "After cancel")).to be_valid

    team.retrospectives.create!(title: "After cancel", created_by: facilitator).update!(status: :closed, closed_at: Time.current)
    expect(build_retro(team, facilitator, title: "After close")).to be_valid
  end

  it "enforces one running retrospective per team at the database" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    team.retrospectives.create!(title: "First", created_by: facilitator)

    duplicate = build_retro(team, facilitator, title: "Second")
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
