require "rails_helper"

RSpec.describe "System administration", type: :request do
  def create_collecting_retro(facilitator:, member:, team:)
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    retro.participations.create!(user: member)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    retro
  end

  it "lets a system admin access administration, create teams, and stay off those teams" do
    admin = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    unconfirmed = create_user(name: "Unconfirmed", confirmed: false)

    sign_in(admin)
    get root_path
    expect(response.body).to include("System administration")
    expect(response.body).not_to include("New team")
    admin_nav = response.parsed_body.at_css("header nav a.app-nav-admin")
    expect(admin_nav["aria-label"]).to eq("System administration")
    expect(admin_nav.at_css(".app-nav-admin-full").text).to eq("System administration")
    expect(admin_nav.at_css(".app-nav-admin-short").text).to eq("Admin")
    expect(admin_nav.at_css(".app-nav-admin-short")["aria-hidden"]).to eq("true")

    get system_admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manage teams")
    expect(response.body).to include("Manage system admins")

    get new_system_admin_team_path
    expect(response.body).to include("Initial facilitator")
    expect(response.body).to include("Jordan")
    expect(response.body).not_to include("Unconfirmed")
    create_team = response.parsed_body.at_css("form.create-team-form")
    expect(create_team.at_css("input[name='team[name]']")["class"]).to include("workspace-field")
    expect(create_team.at_css("select[name='facilitator_id']")["class"]).to include("workspace-field")
    expect(create_team.at_css("input[name='team[name]']").ancestors.find { |node| node["class"].to_s.include?("action-item-control") }).to be_present
    expect(create_team.at_css("select[name='facilitator_id']").ancestors.find { |node| node["class"].to_s.include?("action-item-control") }).to be_present
    expect(create_team.at_css("select[name='facilitator_id']").parent.at_css("svg.action-item-field-icon")).to be_present

    expect do
      post system_admin_teams_path, params: { team: { name: "Platform" }, facilitator_id: jordan.id }
    end.to change(Team, :count).by(1)

    platform = Team.find_by!(name: "Platform")
    expect(response).to redirect_to(system_admin_team_path(platform))
    expect(platform.created_by).to eq(admin)
    expect(platform.memberships.find_by(user: jordan)).to be_facilitator
    expect(platform.memberships.find_by(user: admin)).to be_nil
    expect(admin.reload.teams).to be_empty

    post system_admin_teams_path, params: { team: { name: "Mobile" }, facilitator_id: jordan.id }
    expect(Team.active.order(:name).pluck(:name)).to contain_exactly("Mobile", "Platform")
    expect(Team.find_by!(name: "Mobile").memberships.find_by(user: admin)).to be_nil

    get system_admin_teams_path
    team_links = response.parsed_body.css("a.home-team-link")
    expect(team_links.map { |link| link.at_css(".home-team-link-name")&.text }).to include("Mobile", "Platform")
    expect(team_links.map { |link| link["href"] }).to include(system_admin_team_path(platform))
    expect(team_links.first.at_css("svg.home-team-link-icon")).to be_present

    post system_admin_teams_path, params: { team: { name: "Platform" }, facilitator_id: jordan.id }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Name has already been taken")
    expect(Team.where(name: "Platform").count).to eq(1)

    post system_admin_teams_path, params: { team: { name: "Data" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Team.find_by(name: "Data")).to be_nil

    post system_admin_teams_path, params: { team: { name: "Data" }, facilitator_id: unconfirmed.id }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Team.find_by(name: "Data")).to be_nil
  end

  it "lets a facilitator promote a teammate and refuses last-facilitator removal" do
    jordan = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    other = create_user(name: "Morgan")
    platform = create_team_with_roles(facilitator: jordan, members: [alice], name: "Platform")
    mobile = create_team_with_roles(facilitator: other, members: [alice], name: "Mobile")
    alice_on_platform = platform.memberships.find_by!(user: alice)
    jordan_on_platform = platform.memberships.find_by!(user: jordan)

    sign_in(jordan)
    patch facilitator_team_membership_path(platform, alice_on_platform), params: { role: "facilitator" }
    expect(alice_on_platform.reload).to be_facilitator
    expect(mobile.memberships.find_by(user: alice)).to be_member

    patch facilitator_team_membership_path(mobile, mobile.memberships.find_by!(user: alice)), params: { role: "facilitator" }
    expect(response).to redirect_to(root_path)
    expect(mobile.memberships.find_by(user: alice).reload).to be_member

    patch facilitator_team_membership_path(platform, jordan_on_platform), params: { role: "member" }
    expect(jordan_on_platform.reload).to be_member
    expect(platform.current_memberships.facilitator).to contain_exactly(alice_on_platform)

    sign_in(alice)
    patch facilitator_team_membership_path(platform, alice_on_platform), params: { role: "member" }
    expect(response).to redirect_to(facilitator_team_path(platform))
    expect(alice_on_platform.reload).to be_facilitator
    expect(flash[:alert]).to include("This team must have at least one Facilitator.")

    delete facilitator_team_membership_path(platform, alice_on_platform)
    expect(response).to redirect_to(facilitator_team_path(platform))
    expect(alice_on_platform.reload).to be_facilitator
    expect(flash[:alert]).to include("This team must have at least one Facilitator.")
  end

  it "lets a system admin manage other admins without changing team roles" do
    priya = create_user(name: "Priya", system_admin: true)
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: create_user(name: "Jordan"), members: [alice])

    sign_in(priya)
    get system_admin_admins_path
    expect(response.body).to include("Priya")
    expect(response.body).to include("Alice")
    add_form = response.parsed_body.at_css("form.add-admin-form")
    add_admin = add_form.at_css("select[name='user_id']")
    expect(add_admin["class"]).to include("workspace-field")
    expect(add_admin["class"]).not_to include("workspace-filter-field")
    expect(add_admin.ancestors.find { |node| node["class"].to_s.include?("action-item-control") }).to be_present
    expect(add_admin.parent.at_css("svg.action-item-field-icon")).to be_present

    post system_admin_admins_path, params: { user_id: alice.id }
    expect(alice.reload).to be_system_admin
    expect(team.memberships.find_by(user: alice)).to be_member
    expect(alice).not_to be_facilitator

    delete system_admin_admin_path(priya)
    expect(response).to redirect_to(system_admin_admins_path)
    expect(flash[:alert]).to include("Use Leave System Admin role to give up your own privileges.")
    expect(priya.reload).to be_system_admin
    expect(alice.reload).to be_system_admin

    delete system_admin_admin_path(alice)
    expect(response).to redirect_to(system_admin_admins_path)
    expect(flash[:notice]).to eq("Alice is no longer a System Admin.")
    expect(alice.reload).not_to be_system_admin
    expect(priya.reload).to be_system_admin
  end

  it "lets a system admin leave the role when another admin remains" do
    alice = create_user(name: "Alice", system_admin: true)
    bob = create_user(name: "Bob", system_admin: true)

    sign_in(alice)
    get system_admin_admins_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("You can't leave the System Admin role because you are the only System Admin.")

    alice_row = response.parsed_body.css("article.admin-row").find { |row| row.text.include?("Alice") }
    bob_row = response.parsed_body.css("article.admin-row").find { |row| row.text.include?("Bob") }
    leave_form = alice_row.at_css("form[action='#{leave_system_admin_admins_path}']")
    remove_form = bob_row.at_css("form[action='#{system_admin_admin_path(bob)}']")

    expect(leave_form).to be_present
    expect(leave_form["data-turbo-confirm"]).to eq("Leave System Admin role?")
    expect(leave_form["data-confirm-description"]).to include("You will lose access to System Administration and will no longer be a System Admin.")
    expect(leave_form["data-confirm-description"]).to include("Another System Admin will remain responsible for system administration.")
    expect(leave_form["data-confirm-accept"]).to eq("Leave System Admin role")
    expect(leave_form["data-confirm-cancel"]).to eq("Cancel")
    expect(leave_form["data-confirm-variant"]).to eq("danger")
    expect(leave_form.at_css("[type='submit']").text).to include("Leave System Admin role")
    expect(alice_row.text).not_to match(/\bRemove\b/)

    expect(remove_form).to be_present
    expect(remove_form.at_css("[type='submit']").text).to include("Remove")
    expect(bob_row.at_css("form[action='#{leave_system_admin_admins_path}']")).to be_nil

    delete leave_system_admin_admins_path
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("You have left the System Admin role.")
    expect(flash[:alert]).to be_nil
    follow_redirect!
    expect(response.body).to include("You have left the System Admin role.")
    expect(response.body).not_to include("You are not allowed to do that")
    expect(alice.reload).not_to be_system_admin
    expect(bob.reload).to be_system_admin
  end

  it "does not let the only system admin leave the role" do
    alice = create_user(name: "Alice", system_admin: true)

    sign_in(alice)
    get system_admin_admins_path
    expect(response.body).to include("You can't leave the System Admin role because you are the only System Admin.")
    expect(response.parsed_body.at_css("form[action='#{leave_system_admin_admins_path}']")).to be_nil
    expect(response.parsed_body.css("button").map { |button| button.text.strip }).not_to include("Leave System Admin role", "Remove")

    delete leave_system_admin_admins_path
    expect(response).to redirect_to(system_admin_admins_path)
    expect(flash[:alert]).to eq("You can't leave the System Admin role because you are the only System Admin.")
    expect(alice.reload).to be_system_admin

    delete system_admin_admin_path(alice)
    expect(response).to redirect_to(system_admin_admins_path)
    expect(flash[:alert]).to include("Use Leave System Admin role to give up your own privileges.")
    expect(alice.reload).to be_system_admin
  end

  it "does not let system admin status unlock retrospective content" do
    admin = create_user(name: "Priya", system_admin: true)
    facilitator = create_user(name: "Jordan")
    member = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [member])
    retro = create_collecting_retro(facilitator: facilitator, member: member, team: team)

    sign_in(admin)
    get facilitator_team_path(team)
    expect(response).to redirect_to(root_path)

    get facilitator_retrospective_path(retro)
    expect(response).to redirect_to(root_path)

    get participant_retrospective_path(retro)
    expect(response).to redirect_to(root_path)

    get facilitator_retrospective_meeting_path(retro)
    expect(response).to redirect_to(root_path)

    expect(FeedbackItem.column_names).not_to include("user_id", "participation_id")
    expect(FeedbackItem.reflect_on_association(:user)).to be_nil
  end

  it "uses the shared empty-state cards when admin lists have nothing to show" do
    admin = create_user(name: "Priya", system_admin: true)

    sign_in(admin)
    get system_admin_teams_path
    expect(response).to have_http_status(:ok)

    page = response.parsed_body
    active_empty = page.css(".home-card").find { |card| card.text.include?("No active teams") }
    archived_empty = page.css(".home-card").find { |card| card.text.include?("No archived teams") }
    expect(active_empty).to be_present
    expect(active_empty.at_css("p.font-semibold").text).to eq("No active teams")
    expect(active_empty.text).to include("There are no active teams in the workspace yet.")
    expect(archived_empty).to be_present
    expect(archived_empty.at_css("p.font-semibold").text).to eq("No archived teams")
    expect(archived_empty.text).to include("There are no archived teams in the workspace yet.")
    expect(response.body).not_to include("No active teams.")
    expect(response.body).not_to include("No archived teams.")
  end

  it "uses the shared empty-state card when an admin team has no current members" do
    admin = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: jordan, name: "Platform")
    team.memberships.find_by!(user: jordan).update!(deactivated_at: Time.current)

    sign_in(admin)
    get system_admin_team_path(team)
    expect(response).to have_http_status(:ok)

    empty = response.parsed_body.css(".home-card").find { |card| card.text.include?("No current members") }
    expect(empty).to be_present
    expect(empty.at_css("p.font-semibold").text).to eq("No current members")
    expect(empty.text).to include("There are no current members to display yet.")
    expect(response.body).not_to include("No current members.")
  end

  it "lets a system admin archive a team they do not belong to" do
    admin = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: jordan, name: "Platform")

    sign_in(admin)
    get system_admin_team_path(team)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jordan")
    expect(response.body).to include("Members (1)")
    expect(response.body).not_to include("Team facilitators manage membership and retrospectives for this team.")
    expect(response.body).not_to include("Current retrospective")
    expect(response.body).not_to include("Current action items")
    expect(response.parsed_body.at_css(".member-avatar")).to be_present

    get new_system_admin_team_archive_path(team)
    expect(response.body).to include("This action cannot be undone.")

    post system_admin_team_archive_path(team), params: { confirmation_name: "Platform" }
    expect(team.reload).to be_archived
    expect(team.current_memberships).to be_empty
  end

  it "lets a system admin reset their password without bootstrap" do
    admin = create_user(name: "Priya", email: "priya@example.com", system_admin: true)
    raw = admin.issue_password_reset_token!

    patch password_reset_path(token: raw), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(root_path)
    expect(admin.reload.authenticate("newpassword")).to eq(admin)
    expect(admin).to be_system_admin
  end
end

RSpec.describe Users::CreateSystemAdmin do
  it "creates a confirmed system admin with no team membership" do
    user = described_class.new(
      name: "Priya",
      email: "priya@example.com",
      password: "password123",
      password_confirmation: "password123"
    ).call

    expect(user).to be_system_admin
    expect(user).to be_confirmed
    expect(user.memberships).to be_empty
    expect(user).not_to be_facilitator
    expect(Team.count).to eq(0)
  end

  it "refuses to bootstrap a second initial system admin" do
    create_user(name: "Priya", system_admin: true)

    expect do
      described_class.new(
        name: "Jordan",
        email: "jordan@example.com",
        password: "password123",
        password_confirmation: "password123"
      ).call
    end.to raise_error(described_class::Error, described_class::ALREADY_EXISTS_MESSAGE)
    expect(User.find_by(email: "jordan@example.com")).to be_nil
  end

  it "is not invoked during application boot" do
    boot_files = [
      Rails.root.join("config/application.rb"),
      Rails.root.join("config/environment.rb"),
      Rails.root.join("config/environments/production.rb"),
      Rails.root.join("Rakefile")
    ]
    boot_files.each do |path|
      expect(File.read(path)).not_to include("create_system_admin")
    end
    expect(File).to exist(Rails.root.join("lib/tasks/retroreflect.rake"))
  end
end
