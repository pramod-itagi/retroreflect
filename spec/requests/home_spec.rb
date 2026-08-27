require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  def setup_home
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    platform = create_team_with_roles(facilitator: facilitator, members: [alice])
    platform.update!(name: "Platform")
    payments = Team.create!(name: "Payments", created_by: facilitator)
    payments.memberships.create!(user: facilitator, role: :facilitator)
    draft = payments.retrospectives.create!(title: "Sprint 25 setup", sprint_label: "Sprint 25", created_by: facilitator)
    {
      facilitator: facilitator,
      alice: alice,
      platform: platform,
      payments: payments,
      draft: draft
    }
  end

  it "shows current team work and drafts, not historical retrospectives" do
    context = setup_home
    collecting = context[:platform].retrospectives.create!(
      title: "Sprint 24 collecting",
      sprint_label: "Sprint 24",
      created_by: context[:facilitator]
    )
    collecting.participations.create!(user: context[:alice])
    collecting.update!(status: :collecting, collecting_started_at: Time.current)
    context[:platform].retrospectives.create!(
      title: "Ancient closed retro",
      sprint_label: "Sprint 1",
      created_by: context[:facilitator],
      status: :closed,
      closed_at: 1.month.ago
    )

    sign_in(context[:facilitator])
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Active teams")
    expect(response.body).to include("Platform")
    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).to include("Collecting")
    expect(response.body).to include("0 / 1 submitted")
    expect(response.body).to include("Sprint 25 setup")
    expect(response.body).to include("Continue Setup")
    expect(response.body).not_to include("Ancient closed retro")
    expect(response.body).not_to include("Recent Retrospectives")
    expect(response.body).not_to include("Previous Retrospectives")
    expect(response.body).not_to include("Previous Retros")
  end

  it "lets a facilitator start a retrospective when the team has none running" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    team.update!(name: "Growth")

    sign_in(facilitator)
    get root_path

    expect(response.body).to include("No active retrospective")
    expect(response.body).to include("Start Retrospective")
    expect(response.body).to include(new_facilitator_team_retrospective_path(team))
  end

  it "continues to show action items that need attention, not completed history" do
    context = setup_home
    open_item = context[:platform].action_items.create!(
      title: "Fix flaky spec",
      owner: context[:alice],
      created_by: context[:facilitator],
      due_on: Date.current,
      status: :open
    )
    context[:platform].action_items.create!(
      title: "Old completed work",
      owner: context[:alice],
      created_by: context[:facilitator],
      due_on: Date.current - 14,
      status: :completed,
      completed_at: Time.current,
      completed_by: context[:alice]
    )

    sign_in(context[:alice])
    get root_path

    expect(response.body).to include("Action items needing attention")
    expect(response.body).to include(open_item.title)
    expect(response.body).not_to include("Old completed work")
  end

  it "includes the updated header navigation" do
    facilitator = create_user(name: "Jordan")
    create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)
    get root_path

    nav = response.parsed_body.at_css("header nav").text
    expect(nav).to include("Home")
    expect(nav).to include("Teams")
    expect(nav).to include("Retrospectives")
    expect(nav).to include("Actions")
    expect(nav).not_to include("System Administration")
    expect(nav).not_to include("Previous Retros")
    expect(nav).not_to include("Action items")
  end
end
