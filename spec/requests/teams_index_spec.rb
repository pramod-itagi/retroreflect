require "rails_helper"

RSpec.describe "Teams listing", type: :request do
  def listed_team_names
    response.parsed_body.css("ul li article .display-face").map { |heading| heading.text.strip }
  end

  it "lets a regular member see the teams they belong to" do
    jordan = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    platform = create_team_with_roles(facilitator: jordan, members: [alice], name: "Platform Team")

    sign_in(alice)
    get facilitator_teams_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css(".listing-lede").text).to eq("See the teams you're part of and follow their retrospectives.")
    expect(response.body).to include("Platform Team")
    expect(response.body).to include("Member · Active")
    expect(response.body).to include("View team")
    expect(response.body).to include(facilitator_team_path(platform))
    expect(response.parsed_body.at_css("ul li article .display-face").name).to eq("p")
    expect(response.parsed_body.css("ul li article a").map { |anchor| anchor.text.strip }).to eq(["View team"])
    expect(response.body).not_to include("No teams yet")
    expect(response.parsed_body.text).not_to include("You don't have any teams assigned to you yet.")
    expect(response.body).not_to include("Open team")
  end

  it "lets a regular member see every team they belong to" do
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    alice = create_user(name: "Alice")
    create_team_with_roles(facilitator: jordan, members: [alice], name: "Platform")
    create_team_with_roles(facilitator: morgan, members: [alice], name: "Growth")

    sign_in(alice)
    get facilitator_teams_path

    expect(listed_team_names).to contain_exactly("Platform", "Growth")
    expect(response.body.scan("Member · Active").size).to eq(2)
    expect(response.body).not_to include("No teams yet")
  end

  it "lets a facilitator keep seeing the teams they facilitate" do
    jordan = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    platform = create_team_with_roles(facilitator: jordan, members: [alice], name: "Platform")

    sign_in(jordan)
    get facilitator_teams_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manage the teams you facilitate and keep their retrospectives moving.")
    expect(listed_team_names).to contain_exactly("Platform")
    expect(response.body).to include("Open team")
    expect(response.body).to include(facilitator_team_path(platform))
    expect(response.body).not_to include("Member · Active")
    expect(response.parsed_body.at_css(".listing-lede").text).not_to include("See the teams you're part of")
  end

  it "lists facilitated and member teams together without duplicates" do
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    create_team_with_roles(facilitator: jordan, name: "Platform")
    create_team_with_roles(facilitator: morgan, members: [jordan], name: "Growth")

    sign_in(jordan)
    get facilitator_teams_path

    expect(listed_team_names).to contain_exactly("Platform", "Growth")
    expect(response.body).to include("Open team")
    expect(response.body).to include("View team")
    expect(response.body).to include("Member · Active")
    expect(response.body).to include("Manage the teams you facilitate and keep their retrospectives moving.")
  end

  it "lets a system admin see every active team in their workspace" do
    priya = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    morgan = create_user(name: "Morgan")
    platform = create_team_with_roles(facilitator: jordan, name: "Platform")
    growth = create_team_with_roles(facilitator: morgan, name: "Growth")

    sign_in(priya)
    get facilitator_teams_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manage all teams and oversee retrospectives across the workspace.")
    expect(listed_team_names).to contain_exactly("Platform", "Growth")
    expect(response.body).to include(system_admin_team_path(platform))
    expect(response.body).to include(system_admin_team_path(growth))
    expect(response.body).not_to include(facilitator_team_path(platform))
    expect(response.body).not_to include("No teams yet")
  end

  it "shows the member empty state only when the user has no teams" do
    user = create_user(name: "Casey")

    sign_in(user)
    get facilitator_teams_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No teams yet")
    expect(response.parsed_body.at_css(".listing-stack").text).to include("You haven't been added to any teams yet.")
    expect(response.parsed_body.text).not_to include("You don't have any teams assigned to you yet.")
  end

  it "does not let a regular member use facilitator team-management actions" do
    jordan = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    extra = create_user(name: "Extra")
    platform = create_team_with_roles(facilitator: jordan, members: [alice], name: "Platform")

    sign_in(alice)
    get facilitator_team_path(platform)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("People on this team and their roles.")
    expect(response.body).not_to include("Make facilitator")
    expect(response.body).not_to include("Make member")
    expect(response.body).not_to include("Add person")
    expect(response.body).not_to include("New retrospective")
    expect(response.body).not_to include("Archive team")

    expect do
      post facilitator_team_memberships_path(platform), params: { user_id: extra.id, role: "member" }
    end.not_to change { platform.memberships.count }
    expect(response).to redirect_to(root_path)

    expect do
      post facilitator_team_retrospectives_path(platform), params: {
        retrospective: { title: "Rogue retro", sprint_label: "Sprint 99" },
        participant_ids: [alice.id]
      }
    end.not_to change(Retrospective, :count)
    expect(response).to redirect_to(root_path)

    get new_facilitator_team_retrospective_path(platform)
    expect(response).to redirect_to(root_path)

    post facilitator_team_archive_path(platform), params: { confirmation_name: "Platform" }
    expect(response).to redirect_to(root_path)
    expect(platform.reload).not_to be_archived
  end
end
