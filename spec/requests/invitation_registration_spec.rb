require "rails_helper"

RSpec.describe "Invitation and registration workflows", type: :request do
  include ActiveJob::TestHelper

  def register!(name:, email:)
    perform_enqueued_jobs do
      post registrations_path, params: {
        user: {
          name: name,
          email: email,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    User.find_by!(email: email.strip.downcase)
  end

  def confirm!(user)
    mail = ActionMailer::Base.deliveries.find { |delivery| delivery.to.include?(user.email) }
    token = mail.text_part.body.to_s[%r{/email_confirmations/([^/\s]+)}, 1]
    get email_confirmation_path(token: token)
    user.reload
  end

  def issue_invitation!(participation)
    raw, digest = Token.generate
    participation.update!(invitation_token_digest: digest, invited_at: Time.current)
    raw
  end

  it "does not create an invitation for an email that has no registered account" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)

    expect(Participation.columns_hash.fetch("user_id").null).to be false
    expect(retro.participations.new(user: nil)).not_to be_valid

    sign_in(facilitator)
    post facilitator_retrospective_participations_path(retro), params: { email: "alice@example.com" }
    expect(response).to redirect_to(facilitator_retrospective_path(retro))
    follow_redirect!
    expect(response.body).to include("Select a team member.")
    expect(retro.reload.participations.count).to eq(0)
    expect(User.find_by(email: "alice@example.com")).to be_nil
  end

  it "lets an already registered invited user accept without registering again" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice", email: "alice@example.com")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(participation)

    sign_in(alice)
    get invitation_path(token: raw)

    expect(response).to redirect_to(participant_retrospective_path(retro))
    expect(participation.reload.user).to eq(alice)
    expect(participation).to be_invitation_accepted
  end

  it "does not let a different registered email claim another person's invitation" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice", email: "alice@example.com")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(participation)

    bob = register!(name: "Bob", email: "bob@example.com")
    expect(bob).not_to be_confirmed
    expect(participation.reload.user).to eq(alice)
    expect(bob.participations).to be_empty

    confirm!(bob)
    expect(bob).to be_confirmed
    expect(participation.reload.user).to eq(alice)
    expect(bob.participations).to be_empty

    sign_in(bob)
    get invitation_path(token: raw)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("This invitation is for a different account")
    expect(participation.reload).not_to be_invitation_accepted
    expect(participation.user).to eq(alice)

    get participant_retrospective_path(retro)
    expect(response).to redirect_to(root_path)
  end

  it "lets an uninvited user register, confirm, and use the app without team or retrospective access" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(participation)

    bob = register!(name: "Bob", email: "bob@example.com")
    expect(bob).not_to be_confirmed
    expect(bob.memberships).to be_empty
    expect(bob.participations).to be_empty
    expect(response).to redirect_to(new_session_path)
    expect(session[:user_id]).to be_nil

    get root_path
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email: bob.email, password: "password123" }
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Confirm your email")

    confirm!(bob)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Email confirmed.")
    expect(response.body).to include("You are not on any teams yet.")
    expect(response.body).not_to include("New team")
    expect(bob.reload.memberships).to be_empty
    expect(bob.participations).to be_empty

    get facilitator_team_path(team)
    expect(response).to redirect_to(root_path)

    get participant_retrospective_path(retro)
    expect(response).to redirect_to(root_path)

    get invitation_path(token: raw)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("This invitation is for a different account")

    expect do
      post system_admin_teams_path, params: { team: { name: "Rogue team" }, facilitator_id: bob.id }
    end.not_to change(Team, :count)
  end

  it "keeps an unconfirmed invited account from using the invitation until they confirm" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice", email: "alice@example.com", confirmed: false)
    team = create_team_with_roles(facilitator: facilitator)
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)

    expect do
      retro.participations.create!(user: alice)
    end.to raise_error(ActiveRecord::RecordInvalid)

    sign_in(facilitator)
    post facilitator_team_memberships_path(team), params: { user_id: alice.id, role: "member" }
    expect(team.memberships.find_by(user: alice)).to be_nil

    post session_path, params: { email: alice.email, password: "password123" }
    expect(response).to redirect_to(new_session_path)
    expect(alice.reload).not_to be_confirmed
  end

  it "rejects invalid registration input without creating an account" do
    expect do
      post registrations_path, params: {
        user: { name: "", email: "bob@example.com", password: "password123", password_confirmation: "password123" }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Name can")
    expect(response.body).to include("blank")

    expect do
      post registrations_path, params: {
        user: { name: "Bob", email: "not-an-email", password: "password123", password_confirmation: "password123" }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email is invalid")
  end
end
