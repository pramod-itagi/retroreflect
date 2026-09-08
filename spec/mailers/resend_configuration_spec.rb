require "rails_helper"

RSpec.describe "Resend Action Mailer configuration" do
  def production_mailer_config
    Rails.root.join("config/environments/production.rb").read
  end

  def resend_initializer
    Rails.root.join("config/initializers/resend.rb").read
  end

  it "includes the official Resend gem" do
    expect(Gem.loaded_specs).to have_key("resend")
  end

  it "reads the Resend API key from RESEND_API_KEY" do
    expect(resend_initializer).to include("RESEND_API_KEY")
    expect(resend_initializer).to match(/ENV(?:\.fetch)?\(["']RESEND_API_KEY["']/)
    expect(resend_initializer).not_to match(/re_[A-Za-z0-9]/)
  end

  it "configures production Action Mailer to use the Resend HTTP API" do
    expect(production_mailer_config).to include("delivery_method = :resend")
    expect(production_mailer_config).to include("perform_deliveries = true")
    expect(production_mailer_config).to include("raise_delivery_errors = true")
    expect(production_mailer_config).to include("APP_HOST")
    expect(production_mailer_config).to include("MAILER_FROM")
    expect(production_mailer_config).to include("protocol: \"https\"")
  end

  it "does not configure production to use Resend SMTP" do
    expect(production_mailer_config).not_to include("smtp.resend.com")
    expect(production_mailer_config).not_to include("smtp_settings")
    expect(production_mailer_config).not_to include("SMTP_ADDRESS")
    expect(production_mailer_config).not_to include("delivery_method = :smtp")
  end

  it "keeps confirmation, resend, and password-reset mail on deliver_later" do
    callers = [
      Rails.root.join("app/controllers/registrations_controller.rb").read,
      Rails.root.join("app/controllers/confirmation_resends_controller.rb").read,
      Rails.root.join("app/controllers/password_resets_controller.rb").read
    ]

    expect(callers.join).to include("UserMailer.confirmation")
    expect(callers.join).to include("UserMailer.password_reset")
    expect(callers.join.scan("deliver_later").size).to eq(3)
    expect(callers.join).not_to include("Resend::Emails.send")
  end
end
