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
