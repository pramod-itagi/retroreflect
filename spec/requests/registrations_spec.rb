require "rails_helper"

RSpec.describe "Registration and confirmation", type: :request do
  include ActiveJob::TestHelper

  it "creates an unconfirmed account, emails a confirmation link, and unlocks team membership after confirm" do
    facilitator = create_user(name: "Jordan")
    create_user(name: "Sam")
    team = create_team_with_roles(facilitator: facilitator)

    expect do
      perform_enqueued_jobs do
        post registrations_path, params: {
          user: {
            name: "Alice",
            email: "alice@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end.to change(User, :count).by(1)

    user = User.find_by!(email: "alice@example.com")
    expect(user).not_to be_confirmed
    expect(user.password_digest).to be_present
    expect(user.password_digest).not_to eq("password123")
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Check your email to confirm your account.")

    post session_path, params: { email: user.email, password: "password123" }
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Confirm your email")

    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).to include("Select a confirmed user")
    expect(response.body).not_to include("Alice")

    post facilitator_team_memberships_path(team), params: { user_id: user.id, role: "member" }
    expect(team.memberships.find_by(user: user)).to be_nil
    expect(user.reload).not_to be_confirmed

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["alice@example.com"])
    token = mail.text_part.body.to_s[%r{/email_confirmations/([^/\s]+)}, 1]
    expect(token).to be_present

    delete session_path
    get email_confirmation_path(token: token)
    expect(response).to redirect_to(root_path)
    expect(user.reload).to be_confirmed
    expect(user.confirmation_token_digest).to be_nil

    get email_confirmation_path(token: token)
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to include("Confirmation link is invalid or expired.")
    expect(user.reload).to be_confirmed

    delete session_path
    sign_in(facilitator)
    get facilitator_team_path(team)
    expect(response.body).to include("Alice")

    post facilitator_team_memberships_path(team), params: { user_id: user.id, role: "member" }
    expect(team.memberships.find_by(user: user)).to be_member
  end

  it "rejects invalid confirmation tokens" do
    user = create_user(name: "Alice", email: "alice@example.com", confirmed: false)

    get email_confirmation_path(token: "not-a-real-token")
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Confirmation link is invalid or expired.")
    expect(user.reload).not_to be_confirmed
  end

  it "rejects duplicate emails, including different case and surrounding whitespace" do
    create_user(name: "Ada", email: "ada@example.com")

    expect do
      post registrations_path, params: {
        user: {
          name: "Another Alice",
          email: "ada@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email has already been taken")
    expect(response.body).to include("Another Alice")

    expect do
      post registrations_path, params: {
        user: {
          name: "Cased Ada",
          email: "  ADA@example.com  ",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(User.where(email: "ada@example.com").count).to eq(1)
  end

  it "rejects mismatched or missing password confirmation and short passwords" do
    expect do
      post registrations_path, params: {
        user: {
          name: "Bee",
          email: "bee@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password confirmation")

    expect do
      post registrations_path, params: {
        user: {
          name: "Cee",
          email: "cee@example.com",
          password: "password123"
        }
      }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password confirmation")

    expect do
      post registrations_path, params: {
        user: {
          name: "Dee",
          email: "dee@example.com",
          password: "short",
          password_confirmation: "short"
        }
      }
    end.not_to change(User, :count)
    expect(response.body).to include("Password is too short")
  end

  it "does not include a role selector on registration" do
    get new_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Create an account")
    expect(response.body).to include("Back to sign in")
    expect(response.body).to include(new_session_path)
    expect(response.body).not_to include("Facilitator")
    expect(response.body).not_to include('name="user[role]"')
  end

  it "enforces the same password length on reset as on registration" do
    user = create_user(name: "Ada", email: "ada@example.com")
    raw = user.issue_password_reset_token!

    patch password_reset_path(token: raw), params: {
      user: { password: "short", password_confirmation: "short" }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password is too short")
    expect(user.reload.authenticate("password123")).to eq(user)

    patch password_reset_path(token: raw), params: {
      user: { password: "newpassword" }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate("password123")).to eq(user)
  end
end
