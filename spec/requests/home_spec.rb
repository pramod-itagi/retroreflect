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
    expect(response.body).to include("Your teams")
    expect(response.body).to include("Platform")
    expect(response.body).to include(facilitator_team_path(context[:platform]))
    team_links = response.parsed_body.css("a.home-team-link")
    platform_link = team_links.find { |link| link.text.include?("Platform") }
    expect(platform_link).to be_present
    expect(platform_link["href"]).to eq(facilitator_team_path(context[:platform]))
    expect(team_links.map { |link| link["href"] }).to include(facilitator_team_path(context[:platform]))
    expect(response.body).to include("home-team-link")
    your_teams = response.parsed_body.css("ul").find { |list| list.at_css("a.home-team-link") }
    expect(your_teams).to be_present
    expect(your_teams["class"]).to include("gap-4")
    expect(your_teams.css("a.home-team-link").size).to eq(2)
    expect(your_teams.css("li").size).to eq(2)
    expect(your_teams.css("article.home-card").size).to eq(2)
    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).to include("Collecting")
    expect(response.body).to include("0 / 1 submitted")
    expect(response.body).to include("Sprint 25 setup")
    expect(response.body).to include("Continue setup")
    expect(response.body).to include("Make room for what your team is learning.")
    expect(response.body).not_to include("Ancient closed retro")
    expect(response.body).not_to include("Recent Retrospectives")
    expect(response.body).not_to include("Previous Retrospectives")
    expect(response.body).not_to include("Previous Retros")
    expect(response.body).not_to include("Draft retrospectives")
    expect(response.body).not_to include("View all")
  end

  it "lets a facilitator start a retrospective when the team has none running" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    team.update!(name: "Growth")

    sign_in(facilitator)
    get root_path

    expect(response.body).to include("No active retrospective")
    expect(response.body).to include("Create retrospective")
    expect(response.body).to include(new_facilitator_team_retrospective_path(team))
    expect(response.body).to include(facilitator_team_path(team))

    team_links = response.parsed_body.css("a[href='#{facilitator_team_path(team)}']")
    idle_link = team_links.find { |link| link["class"].to_s.include?("workspace-team-link") }
    expect(idle_link).to be_present
    expect(idle_link.text).to include(team.name)
    expect(idle_link["class"]).to include("workspace-team-link")
    expect(idle_link["class"]).not_to include("home-team-link")

    your_teams_link = response.parsed_body.at_css("a.home-team-link")
    expect(your_teams_link["href"]).to eq(facilitator_team_path(team))
    expect(your_teams_link.text).to include(team.name)
    expect(your_teams_link["class"]).not_to include("home-action-primary")
  end

  it "continues to show action items that need attention, not completed history" do
    context = setup_home
    retro = context[:platform].retrospectives.create!(
      title: "Historical actions",
      created_by: context[:facilitator],
      status: :closed,
      closed_at: 1.week.ago
    )
    open_item = context[:platform].action_items.create!(
      title: "Fix flaky spec",
      owner: context[:alice],
      created_by: context[:facilitator],
      retrospective: retro,
      due_on: Date.current,
      status: :open
    )
    completed = context[:platform].action_items.create!(
      title: "Old completed work",
      owner: context[:alice],
      created_by: context[:facilitator],
      retrospective: retro,
      due_on: Date.current
    )
    completed.update!(status: :completed, completed_at: Time.current, completed_by: context[:alice])
    overdue_item = context[:platform].action_items.create!(
      title: "Unblock the deploy",
      owner: context[:alice],
      created_by: context[:facilitator],
      retrospective: retro,
      due_on: Date.current,
      status: :open
    )
    overdue_item.update!(due_on: Date.current - 1)

    sign_in(context[:alice])
    get root_path

    expect(response.body).to include("Action items needing attention")
    expect(response.body).to include(open_item.title)
    expect(response.body).to include(overdue_item.title)
    expect(response.body).to include("View all")
    expect(response.body).not_to include("Old completed work")
    expect(response.body).to include("Due #{open_item.due_on.strftime("%b #{open_item.due_on.day}, %Y")}")
    expect(response.body).to include("Due #{overdue_item.due_on.strftime("%b #{overdue_item.due_on.day}, %Y")}")
    expect(response.body).to include("Overdue")
    expect(response.body).not_to include(open_item.due_on.iso8601)
    expect(response.body).not_to include(overdue_item.due_on.iso8601)
    attention_list = response.parsed_body.css("ul").find { |list| list.text.include?(open_item.title) }
    expect(attention_list).to be_present
    expect(attention_list["class"]).to include("gap-4")
    expect(attention_list.css("li").size).to eq(2)
    expect(attention_list.css("article.home-card").size).to eq(2)
    open_link = attention_list.at_css("a[href='#{participant_action_items_path(anchor: "action-item-#{open_item.id}")}']")
    overdue_link = attention_list.at_css("a[href='#{participant_action_items_path(anchor: "action-item-#{overdue_item.id}")}']")
    expect(open_link).to be_present
    expect(open_link.text).to include("Open")
    expect(open_link["class"]).to include("home-team-link")
    expect(open_link["aria-label"]).to eq("Open #{open_item.title}")
    expect(overdue_link).to be_present
    expect(overdue_link.text).to include("Open")
    expect(overdue_link["aria-label"]).to eq("Open #{overdue_item.title}")
    view_all = response.parsed_body.css("a").find { |link| link.text.strip == "View all" }
    expect(view_all["href"]).to eq(participant_action_items_path)

    get participant_action_items_path
    expect(response.parsed_body.at_css("#action-item-#{open_item.id}")).to be_present
    expect(response.body).to include("Old completed work")
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
    expect(nav).to include("Action items")
    action_items_link = response.parsed_body.at_css("header nav a[href='#{participant_action_items_path}']")
    expect(action_items_link).to be_present
    expect(action_items_link.text).to include("Action items")
    expect(nav).not_to include("System administration")
    expect(nav).not_to include("Previous Retros")
    expect(nav).not_to include("Actions")

    footer = response.parsed_body.at_css("footer")
    expect(footer).to be_present
    expect(footer.text).to include("Retroreflect — built for the teams doing the work.")
    expect(footer.text).to include("© 2026 Retroreflect")
    expect(footer.text).to include("Contact")
    contact = footer.at_css("a")
    expect(contact).to be_present
    expect(contact.text.strip).to eq("Contact")
    expect(contact["href"]).to eq("https://github.com/pramod-itagi/retroreflect/issues/new")
    expect(footer.css("a").size).to eq(1)
    expect(footer.text).not_to include("How it works")
    expect(footer.text).not_to include("Our approach")
    expect(footer.text).not_to include("Back to the beginning")
  end

  it "lets a member continue an in-progress retrospective without team-management actions" do
    context = setup_home
    collecting = context[:platform].retrospectives.create!(
      title: "Sprint 24 collecting",
      created_by: context[:facilitator]
    )
    collecting.participations.create!(user: context[:alice])
    collecting.update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(context[:alice])
    get root_path

    expect(response.body).to include("Sprint 24 collecting")
    expect(response.body).to include("Continue")
    expect(response.body).to include(participant_retrospective_path(collecting))
    expect(response.body).not_to include("Create retrospective")
    expect(response.body).not_to include("Start Retrospective")
    expect(response.body).not_to include("New team")

    your_teams = response.parsed_body.css("ul").find { |list| list.at_css("a.home-team-link") }
    expect(your_teams).to be_present
    platform_link = your_teams.css("a.home-team-link").find { |link| link.text.include?("Platform") }
    expect(platform_link).to be_present
    expect(platform_link["href"]).to eq(facilitator_team_path(context[:platform]))
    expect(your_teams.text).to include("Your role: Member")
    expect(response.body).not_to include("Make facilitator")
    expect(response.body).not_to include("Archive team")
  end

  it "keeps a sign-in notice in its own bar above the Home canvas" do
    facilitator = create_user(name: "Jordan")

    post session_path, params: { email: facilitator.email, password: "password123" }
    follow_redirect!

    expect(response.body).to include("Signed in.")
    expect(response.body).to include("home-flash-bar")
    expect(response.body).to include("Make room for what your team is learning.")
    expect(response.body).not_to include("-mt-8")
  end
end
