require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  def with_mailer_url_options(options)
    mailer_was = ActionMailer::Base.default_url_options.dup
    routes_was = Rails.application.routes.default_url_options.dup
    ActionMailer::Base.default_url_options = options
    Rails.application.routes.default_url_options = options
    yield
  ensure
    ActionMailer::Base.default_url_options = mailer_was
    Rails.application.routes.default_url_options = routes_was
  end

  it "includes an absolute confirmation URL" do
    user = create_user(name: "Alice", email: "alice@example.com", confirmed: false)
    raw = user.issue_confirmation_token!
    mail = described_class.confirmation(user, raw)

    expect(mail.to).to eq(["alice@example.com"])
    expect(mail.subject).to eq("Confirm your Retroreflect account")
    expect(mail.text_part.body.to_s).to include("http://www.example.com/email_confirmations/#{raw}")
  end

  it "generates an HTTPS confirmation URL for the production host" do
    with_mailer_url_options(host: "retroreflect.onrender.com", protocol: "https") do
      user = create_user(name: "Alice", email: "alice@example.com", confirmed: false)
      raw = user.issue_confirmation_token!
      mail = described_class.confirmation(user, raw)
      expected = "https://retroreflect.onrender.com/email_confirmations/#{raw}"

      expect(mail.text_part.body.to_s).to include(expected)
      expect(mail.html_part.body.to_s).to include(expected)
    end
  end
end
