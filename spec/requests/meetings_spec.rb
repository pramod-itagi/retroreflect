require "rails_helper"

RSpec.describe "Anonymous meeting board", type: :request do
  def revealed_setup
    facilitator = create_user(name: "Jordan Facilitator")
    alice = create_user(name: "Alice Example")
    bob = create_user(name: "Bob Example")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob])
    retro = team.retrospectives.create!(title: "Retro", sprint_label: "Sprint 12", created_by: facilitator)
    alice_participation = retro.participations.create!(user: alice)
    bob_participation = retro.participations.create!(user: bob)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    add_collecting_draft(alice_participation, retro, :went_well, "The deploy pipeline was stable")
    add_collecting_draft(bob_participation, retro, :improve, "Handoffs still take too long")
    alice_participation.update!(submitted_at: Time.current)
    Retrospectives::Reveal.new(retro).call
    { facilitator: facilitator, alice: alice, bob: bob, team: team, retro: retro.reload }
  end

  def add_collecting_draft(participation, retro, category, body)
    participation.feedback_drafts.create!(retrospective: retro, category: category, body: body)
  end

  it "shows sprint, submission status, and anonymous notes for a live meeting" do
    setup = revealed_setup

    sign_in(setup[:facilitator])
    get facilitator_retrospective_meeting_path(setup[:retro])

    expect(response).to have_http_status(:ok)
    page = CGI.unescapeHTML(response.body)
    expect(page).to include("Sprint 12")
    expect(page).to include("What went well")
    expect(page).to include("What didn't go well")
    expect(page).to include("What to continue")
    expect(page).to include("What to improve")
    expect(page).to include("1 of 2 submitted")
    expect(page).to include("The deploy pipeline was stable")
    expect(page).not_to include("Handoffs still take too long")
  end

  it "keeps names in status and note bodies on the board, never together" do
    setup = revealed_setup

    sign_in(setup[:facilitator])
    get facilitator_retrospective_meeting_path(setup[:retro])

    doc = response.parsed_body
    status = doc.at_css("[data-meeting-status]").text
    board = doc.at_css("[data-meeting-board]").text

    expect(status).to include("Alice Example")
    expect(status).to include("Bob Example")
    expect(status).to include("Submitted")
    expect(status).to include("Not submitted")
    expect(status).not_to include("The deploy pipeline was stable")
    expect(status).not_to include("Handoffs still take too long")

    expect(board).to include("The deploy pipeline was stable")
    expect(board).not_to include("Handoffs still take too long")
    expect(board).not_to include("Alice Example")
    expect(board).not_to include("Bob Example")
    expect(board).not_to include(setup[:alice].email)
    expect(board).not_to include(setup[:bob].email)
  end

  it "hides the meeting board until notes are revealed" do
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(facilitator)
    get facilitator_retrospective_meeting_path(retro)

    expect(response).to redirect_to(root_path)
  end

  it "does not let a participant or another team's facilitator open the meeting board" do
    setup = revealed_setup
    other_facilitator = create_user(name: "Other Facilitator")
    create_team_with_roles(facilitator: other_facilitator, name: "Mobile")

    sign_in(setup[:alice])
    get facilitator_retrospective_meeting_path(setup[:retro])
    expect(response).to redirect_to(root_path)

    sign_in(other_facilitator)
    get facilitator_retrospective_meeting_path(setup[:retro])
    expect(response).to redirect_to(root_path)
  end
end
