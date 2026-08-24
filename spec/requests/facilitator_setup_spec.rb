require "rails_helper"

RSpec.describe "Facilitator retrospective setup", type: :request do
  it "lets a facilitator create a team, add members, pick a sprint, and select participants" do
    facilitator = create_user(name: "Jordan", email: "jordan@example.com")
    alice = create_user(name: "Alice", email: "alice@example.com")
    bob = create_user(name: "Bob", email: "bob@example.com")
    create_team_with_roles(facilitator: facilitator).update!(name: "Existing")

    sign_in(facilitator)
    post facilitator_teams_path, params: { team: { name: "Platform" } }
    team = Team.find_by!(name: "Platform")
    expect(response).to redirect_to(facilitator_team_path(team))
    expect(team.memberships.find_by(user: facilitator)).to be_facilitator

    post facilitator_team_memberships_path(team), params: { user_id: alice.id, role: "member" }
    post facilitator_team_memberships_path(team), params: { user_id: bob.id, role: "member" }
    expect(team.memberships.find_by(user: alice)).to be_member
    expect(team.memberships.find_by(user: bob)).to be_member

    get new_facilitator_team_retrospective_path(team)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sprint number")
    expect(response.body).to include("Alice")
    expect(response.body).to include("participant_#{alice.id}")
    expect(response.body).not_to include("participant_#{facilitator.id}")

    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Sprint 12 retro", sprint_label: "Sprint 12" },
      participant_ids: [alice.id]
    }
    retro = team.retrospectives.find_by!(title: "Sprint 12 retro")
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    expect(retro.sprint_label).to eq("Sprint 12")
    expect(retro).to be_draft
    expect(retro.participations.map(&:user)).to contain_exactly(alice)

    post facilitator_retrospective_participations_path(retro), params: { user_id: bob.id }
    expect(retro.reload.participations.map(&:user)).to contain_exactly(alice, bob)
  end

  it "asks for confirmation before removing a member" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    membership = team.memberships.find_by!(user: alice)

    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).to include(confirm_facilitator_team_membership_path(team, membership))
    expect(response.body).not_to include("Remove this person?")

    get confirm_facilitator_team_membership_path(team, membership)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Remove Alice from #{team.name}?")
    expect(response.body).to include("Alice will no longer be a member of this team.")

    get facilitator_team_path(team)
    expect(team.memberships.find_by(user: alice)).to be_present

    delete facilitator_team_membership_path(team, membership)
    expect(response).to redirect_to(facilitator_team_path(team))
    expect(team.memberships.find_by(user: alice)).to be_nil
  end

  it "still prevents a facilitator from removing themselves" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    membership = team.memberships.find_by!(user: facilitator)

    sign_in(facilitator)
    get confirm_facilitator_team_membership_path(team, membership)
    expect(response).to have_http_status(:ok)

    delete facilitator_team_membership_path(team, membership)
    expect(response).to redirect_to(facilitator_team_path(team))
    follow_redirect!
    expect(response.body).to include("You cannot remove yourself as a facilitator.")
    expect(team.memberships.find_by(user: facilitator)).to be_facilitator
  end

  it "ignores outsiders and facilitators when building the roster" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    outsider = create_user(name: "Outsider")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])

    sign_in(facilitator)
    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Sprint 8 retro", sprint_label: "Sprint 8" },
      participant_ids: [alice.id, facilitator.id, outsider.id]
    }

    retro = team.retrospectives.find_by!(title: "Sprint 8 retro")
    expect(retro.participations.map(&:user)).to contain_exactly(alice)

    post facilitator_retrospective_participations_path(retro), params: { user_id: facilitator.id }
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    expect(retro.reload.participations.map(&:user)).to contain_exactly(alice)

    post facilitator_retrospective_participations_path(retro), params: { user_id: outsider.id }
    expect(retro.reload.participations.map(&:user)).to contain_exactly(alice)
  end

  it "rejects an invalid sprint label" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)
    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Bad sprint", sprint_label: "Q3 planning" }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(team.retrospectives).to be_empty
  end
end
