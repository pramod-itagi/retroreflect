require "rails_helper"

RSpec.describe "Authentication", type: :request do
  it "requires email confirmation before sign in" do
    create_user(name: "Ada", email: "ada@example.com", confirmed: false)

    post session_path, params: { email: "ada@example.com", password: "password123" }

    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Confirm your email")
  end

  it "rejects invalid credentials" do
    create_user(name: "Ada", email: "ada@example.com")

    post session_path, params: { email: "ada@example.com", password: "wrong-password" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
  end

  it "signs a confirmed user in and out" do
    user = create_user(name: "Ada", email: "ada@example.com")

    post session_path, params: { email: "ada@example.com", password: "password123" }
    expect(response).to redirect_to(root_path)

    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    get facilitator_teams_path
    expect(response).to redirect_to(new_session_path)
    expect(user.reload).to be_confirmed
  end

  it "sends unauthenticated users to sign in and returns them afterward" do
    user = create_user(name: "Ada", email: "ada@example.com")

    get facilitator_teams_path
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email: user.email, password: "password123" }
    expect(response).to redirect_to(facilitator_teams_path)
  end

  it "does not sign in a discarded user" do
    user = create_user(name: "Ada", email: "ada@example.com")
    email = user.email
    user.discard!

    post session_path, params: { email: email, password: "password123" }

    expect(response).to have_http_status(:unprocessable_content)
    get facilitator_teams_path
    expect(response).to redirect_to(new_session_path)
  end

  it "confirms an account from a valid token" do
    user = create_user(name: "Ada", email: "ada@example.com", confirmed: false)
    raw = user.issue_confirmation_token!

    get email_confirmation_path(token: raw)

    expect(response).to redirect_to(root_path)
    expect(user.reload).to be_confirmed
  end

  it "rejects an expired confirmation token" do
    user = create_user(name: "Ada", email: "ada@example.com", confirmed: false)
    raw = user.issue_confirmation_token!
    user.update!(confirmation_sent_at: 3.days.ago)

    get email_confirmation_path(token: raw)

    expect(response).to redirect_to(new_session_path)
    expect(user.reload).not_to be_confirmed
  end

  it "rejects registration with a short password or duplicate email" do
    create_user(name: "Ada", email: "ada@example.com")

    post registrations_path, params: {
      user: { name: "Ada Two", email: "ada@example.com", password: "password123", password_confirmation: "password123" }
    }
    expect(response).to have_http_status(:unprocessable_content)

    post registrations_path, params: {
      user: { name: "Bee", email: "bee@example.com", password: "short", password_confirmation: "short" }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(User.find_by(email: "bee@example.com")).to be_nil
  end

  it "resets a password with a valid token and rejects an expired one" do
    user = create_user(name: "Ada", email: "ada@example.com")
    raw = user.issue_password_reset_token!

    patch password_reset_path(token: raw), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(root_path)
    expect(user.reload.authenticate("newpassword")).to eq(user)

    expired = create_user(name: "Bee", email: "bee@example.com")
    expired_raw = expired.issue_password_reset_token!
    expired.update!(password_reset_sent_at: 3.hours.ago)

    patch password_reset_path(token: expired_raw), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(new_password_reset_path)
    expect(expired.reload.authenticate("password123")).to eq(expired)
  end
end
