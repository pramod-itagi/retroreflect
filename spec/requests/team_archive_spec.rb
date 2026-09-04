require "rails_helper"

RSpec.describe "Team archiving", type: :request do
  def archive_setup
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    alice = create_user(name: "Alice")
    platform = create_team_with_roles(facilitator: jordan, members: [alice])
    platform.update!(name: "Platform")
    growth = Team.create!(name: "Growth", created_by: jordan)
    growth.memberships.create!(user: jordan, role: :facilitator)
    growth.memberships.create!(user: morgan, role: :member)
    { jordan: jordan, morgan: morgan, alice: alice, platform: platform, growth: growth }
  end

  def create_closed_retro(team, facilitator, title: "Sprint 23 closed")
    team.retrospectives.create!(
      title: title,
      sprint_label: "Sprint 23",
      created_by: facilitator,
      status: :closed,
      closed_at: 1.week.ago
    )
  end

  def create_action_item(team, owner:, created_by:, title:, status:)
    attrs = {
      title: title,
      owner: owner,
      created_by: created_by,
      due_on: Date.current,
      status: status
    }
    attrs[:completed_at] = Time.current if status.to_s == "completed"
    attrs[:completed_by] = owner if status.to_s == "completed"
    attrs[:cancelled_at] = Time.current if status.to_s == "cancelled"
    attrs[:cancelled_by] = created_by if status.to_s == "cancelled"
    team.action_items.create!(attrs)
  end

  def post_archive(team, confirmation_name: team.name)
    post facilitator_team_archive_path(team), params: { confirmation_name: confirmation_name }
  end

  it "lets a facilitator see the archive action and blocks a member from the endpoint" do
    setup = archive_setup

    sign_in(setup[:jordan])
    get facilitator_team_path(setup[:platform])
    expect(response.body).to include("Archive team")
    expect(response.body).to include(new_facilitator_team_archive_path(setup[:platform]))

    sign_in(setup[:alice])
    get facilitator_team_path(setup[:platform])
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Archive team")

    get new_facilitator_team_archive_path(setup[:platform])
    expect(response).to redirect_to(root_path)

    post_archive(setup[:platform])
    expect(response).to redirect_to(root_path)
    expect(setup[:platform].reload).not_to be_archived
  end

  it "does not let an unauthenticated user archive a team" do
    setup = archive_setup

    get new_facilitator_team_archive_path(setup[:platform])
    expect(response).to redirect_to(new_session_path)

    post_archive(setup[:platform])
    expect(response).to redirect_to(new_session_path)
    expect(setup[:platform].reload).not_to be_archived
  end

  it "blocks archive when a collecting or discussing retrospective is in session" do
    setup = archive_setup
    collecting = setup[:platform].retrospectives.create!(
      title: "Sprint 24 collecting",
      sprint_label: "Sprint 24",
      created_by: setup[:jordan]
    )
    collecting.update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(setup[:jordan])
    post_archive(setup[:platform])
    expect(setup[:platform].reload).not_to be_archived
    expect(response).to redirect_to(facilitator_team_path(setup[:platform]))
    follow_redirect!
    expect(response.body).to include("Cannot archive this team. This team has an active retrospective, Sprint 24.")

    collecting.update!(status: :discussing, revealed_at: Time.current)
    post_archive(setup[:platform])
    expect(setup[:platform].reload).not_to be_archived
    expect(collecting.reload).to be_discussing
  end

  it "does not block archive for closed or cancelled retrospectives" do
    setup = archive_setup
    create_closed_retro(setup[:platform], setup[:jordan])
    cancelled = setup[:platform].retrospectives.create!(
      title: "Sprint 22 cancelled",
      created_by: setup[:jordan],
      status: :cancelled,
      cancelled_at: Time.current
    )

    sign_in(setup[:jordan])
    post_archive(setup[:platform])
    expect(setup[:platform].reload).to be_archived
    expect(cancelled.reload).to be_cancelled
  end

  it "blocks archive for unresolved action items and allows completed or cancelled items" do
    setup = archive_setup
    create_action_item(setup[:platform], owner: setup[:alice], created_by: setup[:jordan], title: "Open work", status: :open)
    create_action_item(setup[:platform], owner: setup[:alice], created_by: setup[:jordan], title: "In progress work", status: :in_progress)
    create_action_item(setup[:platform], owner: setup[:alice], created_by: setup[:jordan], title: "Ready work", status: :ready_for_review)

    sign_in(setup[:jordan])
    post_archive(setup[:platform])
    expect(setup[:platform].reload).not_to be_archived
    follow_redirect!
    expect(response.body).to include("Cannot archive this team. This team has 3 unresolved action items.")

    setup[:platform].action_items.find_each do |item|
      item.update!(status: :completed, completed_at: Time.current, completed_by: setup[:alice])
    end
    post_archive(setup[:platform])
    expect(setup[:platform].reload).to be_archived
  end

  it "cancels draft retrospectives without publishing feedback" do
    setup = archive_setup
    draft = setup[:platform].retrospectives.create!(title: "Sprint 25 draft", created_by: setup[:jordan])
    draft.participations.create!(user: setup[:alice])

    sign_in(setup[:jordan])
    post_archive(setup[:platform])

    expect(setup[:platform].reload).to be_archived
    expect(draft.reload).to be_cancelled
    expect(FeedbackDraft.where(retrospective: draft)).to be_empty
    expect(FeedbackItem.where(retrospective: draft)).to be_empty
  end

  it "archives the team, deactivates memberships, and keeps users and other-team memberships" do
    setup = archive_setup
    closed = create_closed_retro(setup[:platform], setup[:jordan], title: "Historical platform retro")
    completed = create_action_item(
      setup[:platform],
      owner: setup[:alice],
      created_by: setup[:jordan],
      title: "Shipped work",
      status: :completed
    )
    user_count = User.count

    sign_in(setup[:jordan])
    post_archive(setup[:platform])

    expect(response).to redirect_to(retrospectives_path(team_id: setup[:platform].id))
    expect(setup[:platform].reload).to be_archived
    expect(setup[:platform].current_memberships).to be_empty
    expect(setup[:platform].memberships.count).to eq(2)
    expect(User.count).to eq(user_count)
    expect(setup[:growth].current_memberships.find_by(user: setup[:jordan])).to be_facilitator
    expect(closed.reload).to be_closed
    expect(completed.reload).to be_completed
    expect(setup[:jordan].facilitated_teams).not_to include(setup[:platform])

    get facilitator_teams_path
    listed_teams = response.parsed_body.css("ul li article .display-face").map { |heading| heading.text.strip }
    expect(listed_teams).not_to include("Platform")
    expect(listed_teams).to include("Growth")
    expect(setup[:platform].reload).to be_archived
    expect(response.body).not_to include(facilitator_team_path(setup[:platform]))

    get root_path
    expect(response.body).not_to include("Historical platform retro")
  end

  it "keeps historical anonymous feedback available after archive" do
    setup = archive_setup
    retro = setup[:platform].retrospectives.create!(title: "Sprint 23 closed", sprint_label: "Sprint 23", created_by: setup[:jordan])
    participation = retro.participations.create!(user: setup[:alice])
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Anonymous published note")
    participation.update!(submitted_at: Time.current)
    Retrospectives::Reveal.new(retro).call
    retro.update!(status: :closed, closed_at: Time.current)

    sign_in(setup[:jordan])
    post_archive(setup[:platform])

    get retrospectives_path
    expect(response.body).to include("Sprint 23 closed")

    get facilitator_retrospective_meeting_path(retro)
    expect(response).to have_http_status(:ok)
    board = response.parsed_body.at_css("[data-meeting-board]").text
    expect(board).to include("Anonymous published note")
    expect(board).not_to include(setup[:alice].email)
    expect(FeedbackItem.column_names).not_to include("user_id", "participation_id")
    expect(FeedbackItem.reflect_on_association(:user)).to be_nil
    expect(FeedbackItem.reflect_on_association(:participation)).to be_nil
  end

  it "prevents new work on an archived team" do
    setup = archive_setup
    sign_in(setup[:jordan])
    post_archive(setup[:platform])

    get new_facilitator_team_retrospective_path(setup[:platform])
    expect(response).to redirect_to(root_path)

    post facilitator_team_retrospectives_path(setup[:platform]), params: {
      retrospective: { title: "Should not create", sprint_label: "Sprint 1" }
    }
    expect(setup[:platform].retrospectives.where(title: "Should not create")).to be_empty

    extra = create_user(name: "Extra")
    post facilitator_team_memberships_path(setup[:platform]), params: { user_id: extra.id, role: "member" }
    expect(setup[:platform].current_memberships.where(user: extra)).to be_empty
  end

  it "allows a new active team to reuse an archived team's name" do
    setup = archive_setup
    admin = create_user(name: "Priya", system_admin: true)
    sign_in(setup[:jordan])
    post_archive(setup[:platform])

    sign_in(admin)
    post system_admin_teams_path, params: {
      team: { name: "Platform" },
      facilitator_id: setup[:jordan].id
    }
    expect(response).to redirect_to(system_admin_team_path(Team.order(:id).last))
    expect(Team.active.where(name: "Platform").count).to eq(1)
    expect(Team.where(name: "Platform").count).to eq(2)
  end

  it "leaves the team unchanged when confirmation is cancelled or the typed name does not match" do
    setup = archive_setup

    sign_in(setup[:jordan])
    get new_facilitator_team_archive_path(setup[:platform])
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at("h1").text).to eq("Archive Platform?")
    expect(response.body).to include("Platform")
    expect(response.body).not_to include("Archive this team?")
    expect(response.body).to include("This action cannot be undone.")

    get facilitator_team_path(setup[:platform])
    expect(setup[:platform].reload).not_to be_archived
    expect(setup[:platform].current_memberships.count).to eq(2)

    post_archive(setup[:platform], confirmation_name: "Wrong name")
    expect(response).to redirect_to(new_facilitator_team_archive_path(setup[:platform]))
    expect(setup[:platform].reload).not_to be_archived
  end

  it "lets any facilitator of the team archive it" do
    setup = archive_setup
    setup[:platform].memberships.create!(user: setup[:morgan], role: :facilitator)

    sign_in(setup[:morgan])
    post_archive(setup[:platform])
    expect(setup[:platform].reload).to be_archived
  end

  it "explains both blockers together when an in-session retrospective and unresolved actions exist" do
    setup = archive_setup
    collecting = setup[:platform].retrospectives.create!(
      title: "Sprint 24 collecting",
      sprint_label: "Sprint 24",
      created_by: setup[:jordan]
    )
    collecting.update!(status: :collecting, collecting_started_at: Time.current)
    create_action_item(setup[:platform], owner: setup[:alice], created_by: setup[:jordan], title: "Open work", status: :open)

    sign_in(setup[:jordan])
    post_archive(setup[:platform])
    follow_redirect!
    expect(response.body).to include("Cannot archive this team. This team has an active retrospective, Sprint 24.")
    expect(response.body).to include("This team has 1 unresolved action items.")
    expect(response.body.scan("Cannot archive this team").size).to eq(1)
    expect(setup[:platform].reload).not_to be_archived
    expect(collecting.reload).to be_collecting
  end
end
