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
    add_admin = response.parsed_body.at_css("select[name='user_id']")
    expect(add_admin["class"]).to include("workspace-field")
    expect(add_admin["class"]).not_to include("workspace-filter-field")

    post system_admin_admins_path, params: { user_id: alice.id }
    expect(alice.reload).to be_system_admin
    expect(team.memberships.find_by(user: alice)).to be_member
    expect(alice).not_to be_facilitator

    delete system_admin_admin_path(priya)
    expect(priya.reload).not_to be_system_admin
    expect(alice.reload).to be_system_admin

    sign_in(alice)
    delete system_admin_admin_path(alice)
    expect(response).to redirect_to(system_admin_admins_path)
    follow_redirect!
    expect(response.body).to include("At least one System Admin must remain.")
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

  it "lets a system admin archive a team they do not belong to" do
    admin = create_user(name: "Priya", system_admin: true)
    jordan = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: jordan, name: "Platform")

    sign_in(admin)
    get system_admin_team_path(team)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jordan")
    expect(response.body).not_to include("Current retrospective")
    expect(response.body).not_to include("Current action items")

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
