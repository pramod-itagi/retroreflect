require "rails_helper"

RSpec.describe "Authorization", type: :request do
  def team_context
    facilitator = create_user(name: "Facilitator")
    member = create_user(name: "Member")
    outsider = create_user(name: "Outsider")
    team = create_team_with_roles(facilitator: facilitator, members: [member])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    { facilitator: facilitator, member: member, outsider: outsider, team: team, retro: retro }
  end

  it "redirects unauthenticated users away from protected areas" do
    setup = team_context

    get facilitator_team_path(setup[:team])
    expect(response).to redirect_to(new_session_path)

    get participant_retrospective_path(setup[:retro])
    expect(response).to redirect_to(new_session_path)

    get invitation_path(token: "unused-token")
    expect(response).to redirect_to(new_session_path)

    get retrospectives_path
    expect(response).to redirect_to(new_session_path)
  end

  it "lets a facilitator open the new-team page and create a team" do
    setup = team_context

    sign_in(setup[:facilitator])
    get root_path
    expect(response.body).to include("New team")

    get new_facilitator_team_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Create team")

    expect do
      post facilitator_teams_path, params: { team: { name: "Growth" } }
    end.to change(Team, :count).by(1)

    team = Team.find_by!(name: "Growth")
    expect(response).to redirect_to(facilitator_team_path(team))
    expect(team.memberships.find_by(user: setup[:facilitator])).to be_facilitator
  end

  it "does not let a regular member access team creation" do
    setup = team_context

    sign_in(setup[:member])
    get root_path
    expect(response.body).not_to include("New team")

    get facilitator_teams_path
    expect(response.body).not_to include("New team")

    get new_facilitator_team_path
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("You are not allowed to do that.")

    expect do
      post facilitator_teams_path, params: { team: { name: "Rogue team" } }
    end.not_to change(Team, :count)
    expect(response).to redirect_to(root_path)
    expect(Team.find_by(name: "Rogue team")).to be_nil
  end

  it "does not let an unauthenticated user create a team" do
    get new_facilitator_team_path
    expect(response).to redirect_to(new_session_path)

    expect do
      post facilitator_teams_path, params: { team: { name: "Unauthenticated team" } }
    end.not_to change(Team, :count)
    expect(response).to redirect_to(new_session_path)
    expect(Team.find_by(name: "Unauthenticated team")).to be_nil
  end

  it "does not let a confirmed user without a facilitator role create a team" do
    user = create_user(name: "Newbie")

    sign_in(user)
    get root_path
    expect(response.body).not_to include("New team")

    get new_facilitator_team_path
    expect(response).to redirect_to(root_path)

    expect do
      post facilitator_teams_path, params: { team: { name: "First team" } }
    end.not_to change(Team, :count)
    expect(Team.find_by(name: "First team")).to be_nil
  end

  it "does not let a team member manage the team or add members" do
    setup = team_context
    extra = create_user(name: "Extra")

    sign_in(setup[:member])
    get facilitator_team_path(setup[:team])
    expect(response).to redirect_to(root_path)

    post facilitator_team_memberships_path(setup[:team]), params: { user_id: extra.id, role: "member" }
    expect(response).to redirect_to(root_path)
    expect(setup[:team].memberships.where(user: extra)).to be_empty
  end

  it "does not let a facilitator of one team manage another team" do
    setup = team_context
    other_facilitator = create_user(name: "Other Facilitator")
    create_team_with_roles(facilitator: other_facilitator)

    sign_in(other_facilitator)
    get facilitator_team_path(setup[:team])
    expect(response).to redirect_to(root_path)

    post facilitator_team_memberships_path(setup[:team]), params: { user_id: setup[:outsider].id, role: "member" }
    expect(response).to redirect_to(root_path)
    expect(setup[:team].memberships.where(user: setup[:outsider])).to be_empty
  end

  it "does not let a member use facilitator retrospective actions" do
    setup = team_context

    sign_in(setup[:member])
    get facilitator_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)

    post start_collecting_facilitator_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)
    expect(setup[:retro].reload).to be_draft
  end

  it "does not let a facilitator open the participant collecting view" do
    setup = team_context
    setup[:retro].participations.create!(user: setup[:member])
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(setup[:facilitator])
    get participant_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)
  end

  it "does not let an outsider access a retrospective they were not invited to" do
    setup = team_context
    setup[:retro].participations.create!(user: setup[:member])
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(setup[:outsider])
    get participant_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)
  end
end
