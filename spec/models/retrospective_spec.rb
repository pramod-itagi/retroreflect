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

  it "prevents duplicate sprint numbers for the same team at the database" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    team.retrospectives.create!(
      title: "First",
      created_by: facilitator,
      sprint_number: 1,
      sprint_year: 2026,
      status: :closed,
      closed_at: Time.current
    )

    duplicate = team.retrospectives.build(
      title: "Second",
      created_by: facilitator,
      sprint_number: 1,
      sprint_year: 2026,
      status: :closed,
      closed_at: Time.current
    )
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same sprint number on different teams" do
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    platform = create_team_with_roles(facilitator: jordan, name: "Platform")
    growth = create_team_with_roles(facilitator: morgan, name: "Growth")

    platform.retrospectives.create!(title: "A", created_by: jordan, sprint_number: 1, sprint_year: 2026)
    expect do
      growth.retrospectives.create!(title: "B", created_by: morgan, sprint_number: 1, sprint_year: 2026)
    end.not_to raise_error
  end

  it "assigns the next sprint number from stored numbers and historical labels" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    team.retrospectives.create!(
      title: "Legacy",
      sprint_label: "Sprint 12",
      created_by: facilitator,
      status: :closed,
      closed_at: Time.current
    )

    expect(described_class.next_sprint_number_for(team)).to eq(13)

    team.retrospectives.create!(
      title: described_class.generated_title(13, 2026),
      sprint_label: described_class.sprint_identifier(13, 2026),
      sprint_number: 13,
      sprint_year: 2026,
      created_by: facilitator,
      status: :cancelled,
      cancelled_at: Time.current
    )

    expect(described_class.next_sprint_number_for(team)).to eq(14)
  end
end
