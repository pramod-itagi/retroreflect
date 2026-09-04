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

    get facilitator_retrospective_path(retro)
    expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).to include("Roster")
    expect(response.body).to include("Participants")
    expect(response.body).not_to include("Make facilitator")
    expect(response.body).not_to include("Make member")
    roster = response.parsed_body.at_css("ul.roster-list")
    expect(roster["class"]).to include("divide-y")
    expect(roster.css("li").size).to eq(2)
    expect(roster.css("article.home-card")).to be_empty
    expect(roster.at_css(".member-avatar")).to be_present
    expect(roster.text).to include("Alice")
    expect(roster.text).to include("Not invited")
    remove = response.parsed_body.at_css("ul.roster-list button.member-action-danger")
    expect(remove).to be_present
    expect(remove.text).to include("Remove")
    add_card = response.parsed_body.css(".home-card").find { |card| card.text.include?("Add team member") }
    expect(add_card).to be_present
    expect(add_card.at_css("select[name='user_id']")["class"]).to include("workspace-field")
    expect(add_card.at_css("select[name='user_id']")["class"]).not_to include("workspace-filter-field")
    add_submit = add_card.at_css("[type='submit']")
    expect(add_submit["value"]).to eq("Add to roster")
    expect(add_submit["class"]).to include("home-action-primary")
  end

  it "asks for confirmation before removing a member" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    membership = team.memberships.find_by!(user: alice)

    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).to include("Members")
    page_headings = response.parsed_body.css(".workspace-page h1, .workspace-page h2").map { |heading| [heading.name, heading.text.strip] }
    expect(page_headings).to eq([
      ["h1", team.name],
      ["h2", "Members"],
      ["h2", "Current retrospective"],
      ["h2", "Current action items"],
      ["h2", "Archive team"]
    ])
    expect(response.parsed_body.at_css(".workspace-page h2").text.strip).to eq("Members")
    expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).not_to include("People")
    expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).not_to include("Add person")
    members = response.parsed_body.at_css("ul.team-member-list")
    expect(members["class"]).to include("divide-y")
    expect(members.css("li").size).to eq(2)
    expect(members.css("article.home-card")).to be_empty
    make_facilitator = response.parsed_body.css("button.member-action-btn").find { |button| button.text.include?("Make facilitator") }
    remove = response.parsed_body.at_css("button.member-action-danger")
    expect(make_facilitator).to be_present
    expect(make_facilitator["class"]).not_to include("member-action-danger")
    expect(remove).to be_present
    expect(remove.text).to include("Remove")
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
