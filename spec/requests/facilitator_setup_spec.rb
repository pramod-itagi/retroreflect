require "rails_helper"

RSpec.describe "Facilitator retrospective setup", type: :request do
  it "lets a facilitator create a team, add members, pick a sprint, and select participants" do
    facilitator = create_user(name: "Jordan", email: "jordan@example.com")
    alice = create_user(name: "Alice", email: "alice@example.com")
    bob = create_user(name: "Bob", email: "bob@example.com")
    create_team_with_roles(facilitator: facilitator, name: "Existing")
    team = create_team_with_roles(facilitator: facilitator, name: "Platform")
    expect(team.memberships.find_by(user: facilitator)).to be_facilitator

    sign_in(facilitator)
    post facilitator_team_memberships_path(team), params: { user_id: alice.id, role: "member" }
    post facilitator_team_memberships_path(team), params: { user_id: bob.id, role: "member" }
    expect(team.memberships.find_by(user: alice)).to be_member
    expect(team.memberships.find_by(user: bob)).to be_member

    get new_facilitator_team_retrospective_path(team)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sprint")
    expect(response.body).to include("Sprint 1 (#{Time.zone.now.year})")
    expect(response.body).to include("Retrospective title")
    expect(response.body).to include("Sprint 1 Retrospective - #{Time.zone.now.year}")
    expect(response.body).not_to include('name="retrospective[title]"')
    expect(response.body).not_to include('name="retrospective[sprint_label]"')
    expect(response.body).not_to include('name="retrospective[sprint_number]"')
    expect(response.body).to include("Alice")
    expect(response.body).to include("participant_#{alice.id}")
    expect(response.body).not_to include("participant_#{facilitator.id}")

    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Sprint 12 retro", sprint_label: "Sprint 12" },
      participant_ids: [alice.id]
    }
    retro = team.retrospectives.order(:id).last
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    expect(retro.title).to eq("Sprint 1 Retrospective - #{Time.zone.now.year}")
    expect(retro.sprint_label).to eq("Sprint 1 (#{Time.zone.now.year})")
    expect(retro.sprint_number).to eq(1)
    expect(retro.sprint_year).to eq(Time.zone.now.year)
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
    expect(response.body).to include("Members")
    expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).to include("Members")
    expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).not_to include("People")
    expect(response.parsed_body.css("ul.team-member-list article.home-card").size).to eq(2)
    expect(response.body).to include("Remove Alice from #{team.name}?")
    expect(response.body).to include("Alice will no longer be a member of this team.")
    expect(response.body).to include("data-turbo-confirm")
    expect(response.body).not_to include(confirm_facilitator_team_membership_path(team, membership))
    expect(response.body).not_to include("Remove this person?")
    expect(response.body).to include(facilitator_team_membership_path(team, membership))

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
    expect(response.body).to include("This team must have at least one Facilitator.")
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

    retro = team.retrospectives.order(:id).last
    expect(retro.participations.map(&:user)).to contain_exactly(alice)

    post facilitator_retrospective_participations_path(retro), params: { user_id: facilitator.id }
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    expect(retro.reload.participations.map(&:user)).to contain_exactly(alice)

    post facilitator_retrospective_participations_path(retro), params: { user_id: outsider.id }
    expect(retro.reload.participations.map(&:user)).to contain_exactly(alice)
  end

  it "ignores a client-supplied sprint label" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)
    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Bad sprint", sprint_label: "Q3 planning" }
    }

    retro = team.retrospectives.order(:id).last
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    expect(retro.sprint_label).to eq("Sprint 1 (#{Time.zone.now.year})")
    expect(retro.sprint_number).to eq(1)
  end
end
