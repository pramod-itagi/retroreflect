require "rails_helper"

RSpec.describe "Retrospectives listing", type: :request do
  def create_closed_retro(team, facilitator, title:, sprint:, closed_at:)
    team.retrospectives.create!(
      title: title,
      sprint_label: sprint,
      created_by: facilitator,
      status: :closed,
      closed_at: closed_at
    )
  end

  def listing_setup
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    alice = create_user(name: "Alice")
    platform = create_team_with_roles(facilitator: jordan, members: [alice])
    platform.update!(name: "Platform")
    payments = Team.create!(name: "Payments", created_by: jordan)
    payments.memberships.create!(user: jordan, role: :facilitator)
    growth = Team.create!(name: "Growth", created_by: morgan)
    growth.memberships.create!(user: morgan, role: :facilitator)
    collecting = start_collecting_retro(platform, jordan, alice)
    {
      jordan: jordan,
      morgan: morgan,
      alice: alice,
      platform: platform,
      draft: payments.retrospectives.create!(title: "Sprint 25 draft", sprint_label: "Sprint 25", created_by: jordan),
      collecting: collecting,
      older_closed: create_closed_retro(platform, jordan, title: "Sprint 22 closed", sprint: "Sprint 22", closed_at: 2.months.ago),
      newer_closed: create_closed_retro(platform, jordan, title: "Sprint 23 closed", sprint: "Sprint 23", closed_at: 1.week.ago),
      other: create_closed_retro(growth, morgan, title: "Growth only retro", sprint: "Sprint 1", closed_at: Time.current)
    }
  end

  def start_collecting_retro(team, facilitator, member)
    retro = team.retrospectives.create!(title: "Sprint 24 collecting", sprint_label: "Sprint 24", created_by: facilitator)
    retro.participations.create!(user: member)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    retro
  end

  it "lets an authorized facilitator see active, draft, and previous retrospectives" do
    setup = listing_setup

    sign_in(setup[:jordan])
    get retrospectives_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Active")
    expect(response.body).to include("Drafts")
    expect(response.body).to include("Previous")
    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).to include("Sprint 25 draft")
    expect(response.body).to include("Sprint 23 closed")
    expect(response.body).to include("Sprint 22 closed")
    expect(response.body).to include("Continue Setup")
    expect(response.body).to include("View")
    expect(response.body).not_to include("Growth only retro")

    previous_heading = response.parsed_body.css("h2").find { |heading| heading.text.strip == "Previous" }
    previous_text = previous_heading.parent.text
    expect(previous_text.index("Sprint 23 closed")).to be < previous_text.index("Sprint 22 closed")
  end

  it "does not let a member see another team's retrospectives" do
    setup = listing_setup

    sign_in(setup[:alice])
    get retrospectives_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).not_to include("Sprint 25 draft")
    expect(response.body).not_to include("Growth only retro")
  end

  it "shows empty states when there is nothing to list" do
    user = create_user(name: "Solo")

    sign_in(user)
    get retrospectives_path

    expect(response.body).to include("No active retrospectives")
    expect(response.body).to include("No drafts yet")
    expect(response.body).to include("No previous retrospectives yet")
  end

  it "filters by team, status group, and title search" do
    setup = listing_setup

    sign_in(setup[:jordan])
    get retrospectives_path, params: { status: "draft" }
    expect(response.body).to include("Sprint 25 draft")
    expect(response.body).not_to include("Sprint 24 collecting")
    expect(response.body).not_to include("Sprint 23 closed")

    get retrospectives_path, params: { q: "Sprint 23" }
    expect(response.body).to include("Sprint 23 closed")
    expect(response.body).not_to include("Sprint 25 draft")

    get retrospectives_path, params: { team_id: setup[:platform].id }
    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).not_to include("Sprint 25 draft")
    expect(response.body).not_to include("Growth only retro")

    get retrospectives_path, params: { q: "zzzz-not-a-retrospective" }
    expect(response.body).to include("No retrospectives found")
    expect(response.body).not_to include("Sprint 24 collecting")
  end

  it "opens historical feedback without exposing authors" do
    setup = listing_setup
    setup[:collecting].participations.first.feedback_drafts.create!(
      retrospective: setup[:collecting],
      category: :went_well,
      body: "Anonymous published note"
    )
    setup[:collecting].participations.first.update!(submitted_at: Time.current)
    Retrospectives::Reveal.new(setup[:collecting]).call
    setup[:collecting].update!(status: :closed, closed_at: Time.current)

    sign_in(setup[:jordan])
    get facilitator_retrospective_meeting_path(setup[:collecting])

    expect(response).to have_http_status(:ok)
    board = response.parsed_body.at_css("[data-meeting-board]").text
    expect(board).to include("Anonymous published note")
    expect(board).not_to include(setup[:alice].name)
    expect(board).not_to include(setup[:alice].email)
    expect(FeedbackItem.column_names).not_to include("user_id", "participation_id")
  end

  it "redirects unauthenticated users away from the listing" do
    get retrospectives_path
    expect(response).to redirect_to(new_session_path)
  end
end
