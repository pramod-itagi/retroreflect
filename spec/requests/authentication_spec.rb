require "rails_helper"

RSpec.describe "Authentication", type: :request do
  it "requires email confirmation before sign in" do
    create_user(name: "Ada", email: "ada@example.com", confirmed: false)

    post session_path, params: { email: "ada@example.com", password: "password123" }

    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Confirm your email")
  end

  it "rejects invalid credentials without revealing whether the email exists" do
    create_user(name: "Ada", email: "ada@example.com")

    post session_path, params: { email: "ada@example.com", password: "wrong-password" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
    expect(response.body).not_to include("no account")
    get root_path
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email: "does-not-exist@example.com", password: "password123" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
    expect(response.body).not_to include("no account")

    post session_path, params: { email: "missing@example.com", password: "also-wrong" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")

    post session_path, params: { email: "", password: "" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
    get facilitator_teams_path
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email: "abc", password: "password123" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")

    post session_path, params: { email: "test@", password: "password123" }
    expect(response).to have_http_status(:unprocessable_content)

    post session_path, params: { email: "@example.com", password: "password123" }
    expect(response).to have_http_status(:unprocessable_content)
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

  it "sends the same response for known and unknown reset emails" do
    user = create_user(name: "Ada", email: "ada@example.com")
    notice = "If that account exists, we sent reset instructions."

    expect do
      post password_resets_path, params: { email: user.email }
    end.to have_enqueued_mail(UserMailer, :password_reset)
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include(notice)
    expect(response.body).not_to include("No account")

    expect do
      post password_resets_path, params: { email: "nobody@example.com" }
    end.not_to have_enqueued_mail(UserMailer, :password_reset)
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include(notice)
    expect(response.body).not_to include("No account")
  end

  it "lets a user complete forgot-password from the emailed reset link" do
    user = create_user(name: "Ada", email: "ada@example.com")

    perform_enqueued_jobs do
      post password_resets_path, params: { email: user.email }
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["ada@example.com"])
    token = mail.text_part.body.to_s[%r{/password_resets/([^/]+)/edit}, 1]
    expect(token).to be_present

    get edit_password_reset_path(token: token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Choose a new password")

    patch password_reset_path(token: token), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(root_path)
    expect(user.reload.authenticate("newpassword")).to eq(user)
    expect(user.authenticate("password123")).to be_falsey

    delete session_path
    post session_path, params: { email: user.email, password: "password123" }
    expect(response).to have_http_status(:unprocessable_content)

    post session_path, params: { email: user.email, password: "newpassword" }
    expect(response).to redirect_to(root_path)
  end

  it "rejects invalid, expired, mismatched, and reused password reset tokens" do
    user = create_user(name: "Ada", email: "ada@example.com")

    get edit_password_reset_path(token: "not-a-real-token")
    expect(response).to redirect_to(new_password_reset_path)
    follow_redirect!
    expect(response.body).to include("Reset link is invalid or expired.")

    patch password_reset_path(token: "not-a-real-token"), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(new_password_reset_path)
    expect(user.reload.authenticate("password123")).to eq(user)

    expired_raw = user.issue_password_reset_token!
    user.update!(password_reset_sent_at: 3.hours.ago)
    get edit_password_reset_path(token: expired_raw)
    expect(response).to redirect_to(new_password_reset_path)
    patch password_reset_path(token: expired_raw), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(new_password_reset_path)
    expect(user.reload.authenticate("password123")).to eq(user)

    raw = user.issue_password_reset_token!
    patch password_reset_path(token: raw), params: {
      user: { password: "newpassword", password_confirmation: "different" }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password confirmation")
    expect(user.reload.authenticate("password123")).to eq(user)

    patch password_reset_path(token: raw), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    expect(response).to redirect_to(root_path)

    get edit_password_reset_path(token: raw)
    expect(response).to redirect_to(new_password_reset_path)
    patch password_reset_path(token: raw), params: {
      user: { password: "anotherpassword", password_confirmation: "anotherpassword" }
    }
    expect(response).to redirect_to(new_password_reset_path)
    expect(user.reload.authenticate("newpassword")).to eq(user)
    expect(user.authenticate("anotherpassword")).to be_falsey
  end

  it "redirects an authenticated user away from the sign-in page" do
    user = create_user(name: "Ada", email: "ada@example.com")

    get new_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign in")

    sign_in(user)
    get new_session_path
    expect(response).to redirect_to(root_path)
  end

  it "blocks protected pages after sign out" do
    user = create_user(name: "Ada", email: "ada@example.com")
    team = create_team_with_roles(facilitator: user)

    sign_in(user)
    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    expect(response).to redirect_to(new_session_path)

    get root_path
    expect(response).to redirect_to(new_session_path)

    get facilitator_teams_path
    expect(response).to redirect_to(new_session_path)

    get facilitator_team_path(team)
    expect(response).to redirect_to(new_session_path)

    expect do
      post system_admin_teams_path, params: { team: { name: "Should not create" }, facilitator_id: user.id }
    end.not_to change(Team, :count)
    expect(response).to redirect_to(new_session_path)
  end
end
