require "rails_helper"

RSpec.describe "Confirmation resends", type: :request do
  include ActiveJob::TestHelper

  def success_copy
    ConfirmationResendsController::SUCCESS_MESSAGE
  end

  it "renders the resend confirmation page with an email form and back navigation" do
    get new_confirmation_resend_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Resend confirmation email")
    expect(response.body).to include("Enter your email address and we'll send you a new confirmation link.")
    expect(response.body).to include("Send confirmation email")
    expect(response.body).to include('name="email"')
    expect(response.body).to include("Back to sign in")
    expect(response.body).to include(new_session_path)
  end

  it "sends a new confirmation email for an unconfirmed user and replaces the previous token" do
    user = create_user(name: "Ada", email: "ada@example.com", confirmed: false)
    previous_raw = user.issue_confirmation_token!
    previous_digest = user.confirmation_token_digest
    previous_sent_at = 1.hour.ago
    user.update!(confirmation_sent_at: previous_sent_at)

    expect do
      perform_enqueued_jobs do
        post confirmation_resends_path, params: { email: "  ADA@example.com  " }
      end
    end.not_to change(User, :count)

    expect(response).to redirect_to(sent_confirmation_resends_path)
    follow_redirect!
    expect(response.body).to include("Check your email")
    expect(response.body).to include(success_copy)
    expect(response.body).to include("Back to sign in")
    expect(response.body).not_to include("already confirmed")
    expect(response.body).not_to include("no account")

    user.reload
    expect(user).not_to be_confirmed
    expect(user.confirmation_token_digest).to be_present
    expect(user.confirmation_token_digest).not_to eq(previous_digest)
    expect(user.confirmation_sent_at).to be > previous_sent_at

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["ada@example.com"])
    token = mail.text_part.body.to_s[%r{/email_confirmations/([^/\s]+)}, 1]
    expect(token).to be_present
    expect(token).not_to eq(previous_raw)
    expect(mail.text_part.body.to_s).to include("/email_confirmations/#{token}")

    get email_confirmation_path(token: previous_raw)
    expect(response).to redirect_to(new_session_path)
    expect(user.reload).not_to be_confirmed

    get email_confirmation_path(token: token)
    expect(response).to redirect_to(root_path)
    expect(user.reload).to be_confirmed
  end

  it "does not send mail or change tokens for a confirmed user, but shows the same success page" do
    user = create_user(name: "Ada", email: "ada@example.com")
    digest = user.confirmation_token_digest
    sent_at = user.confirmation_sent_at

    expect do
      post confirmation_resends_path, params: { email: user.email }
    end.not_to have_enqueued_mail(UserMailer, :confirmation)

    expect(response).to redirect_to(sent_confirmation_resends_path)
    follow_redirect!
    expect(response.body).to include(success_copy)
    expect(response.body).not_to include("already confirmed")

    user.reload
    expect(user).to be_confirmed
    expect(user.confirmation_token_digest).to eq(digest)
    expect(user.confirmation_sent_at).to eq(sent_at)
  end

  it "does not create a user or send mail for an unknown email, but shows the same success page" do
    expect do
      expect do
        post confirmation_resends_path, params: { email: "nobody@example.com" }
      end.not_to have_enqueued_mail(UserMailer, :confirmation)
    end.not_to change(User, :count)

    expect(response).to redirect_to(sent_confirmation_resends_path)
    follow_redirect!
    expect(response.body).to include(success_copy)
    expect(response.body).not_to include("no account")
    expect(response.body).not_to include("Nobody")
  end

  it "keeps confirmation-resend responses identical when rate limited" do
    user = create_user(name: "Ada", email: "ada@example.com", confirmed: false)

    AuthThrottle::CONFIRMATION_RESEND_LIMIT.times do
      post confirmation_resends_path, params: { email: user.email }
      expect(response).to redirect_to(sent_confirmation_resends_path)
    end

    expect do
      post confirmation_resends_path, params: { email: user.email }
    end.not_to have_enqueued_mail(UserMailer, :confirmation)

    expect(response).to redirect_to(sent_confirmation_resends_path)
    follow_redirect!
    expect(response.body).to include(success_copy)
    expect(response.body).not_to include("Too many")
    expect(response.body).not_to include("rate")
  end
end
