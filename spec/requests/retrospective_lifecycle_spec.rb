require "rails_helper"

RSpec.describe "One active retrospective per team", type: :request do
  def create_running_retro(team, facilitator, title: "Sprint 12")
    team.retrospectives.create!(title: title, created_by: facilitator)
  end

  it "lets a team with no active retrospective create one" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).to include("New retrospective")

    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Sprint 12 retro", sprint_label: "Sprint 12" }
    }

    expect(team.retrospectives.running.count).to eq(1)
    expect(response).to redirect_to(facilitator_retrospective_path(team.retrospectives.last))
  end

  it "does not let a team create another retrospective while one is active" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    running = create_running_retro(team, facilitator)

    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).not_to include("New retrospective")
    expect(response.body).to include("already has an active retrospective")
    expect(response.body).to include(running.title)

    get new_facilitator_team_retrospective_path(team)
    expect(response).to redirect_to(facilitator_team_path(team))
    follow_redirect!
    expect(response.body).to include("already has an active retrospective")

    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Second retro", sprint_label: "Sprint 13" }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("already has an active retrospective")
    expect(team.retrospectives.count).to eq(1)
  end

  it "shows only the current retrospective on the team page, not closed history" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    closed = team.retrospectives.create!(
      title: "Ancient closed retro",
      sprint_label: "Sprint 1",
      created_by: facilitator,
      status: :closed,
      closed_at: 1.month.ago
    )
    running = create_running_retro(team, facilitator, title: "Sprint 12")

    sign_in(facilitator)
    get facilitator_team_path(team)

    expect(response.body).to include(running.title)
    expect(response.body).not_to include(closed.title)
    expect(response.body).to include("View retrospective history")
    expect(response.body).to include(retrospectives_path(team_id: team.id))
    expect(response.body).not_to include("New retrospective")
  end

  it "lets a team create a new retrospective after the previous one is closed" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    previous = create_running_retro(team, facilitator)
    previous.update!(status: :closed, closed_at: Time.current)

    sign_in(facilitator)
    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Next sprint", sprint_label: "Sprint 13" }
    }

    expect(response).to redirect_to(facilitator_retrospective_path(team.retrospectives.order(:id).last))
    expect(team.retrospectives.running.count).to eq(1)
    expect(team.retrospectives.closed.count).to eq(1)
  end

  it "lets another team create a retrospective while this team has an active one" do
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    platform = create_team_with_roles(facilitator: jordan)
    platform.update!(name: "Platform")
    growth = Team.create!(name: "Growth", created_by: morgan)
    growth.memberships.create!(user: morgan, role: :facilitator)
    create_running_retro(platform, jordan)

    sign_in(morgan)
    post facilitator_team_retrospectives_path(growth), params: {
      retrospective: { title: "Growth sprint 1", sprint_label: "Sprint 1" }
    }

    expect(growth.retrospectives.running.count).to eq(1)
    expect(platform.retrospectives.running.count).to eq(1)
  end
end
