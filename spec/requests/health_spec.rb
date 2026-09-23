require "rails_helper"

RSpec.describe "Health checks", type: :request do
  def health_page_text
    response.parsed_body.text
  end

  it "returns a healthy dashboard when the database is available" do
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("text/html")
    expect(response.body).to include("System Health")
    expect(response.body).to include("All Systems Operational")
    expect(response.body).to include("Application")
    expect(response.body).to include("Healthy")
    expect(response.body).to include("PostgreSQL Database")
    expect(response.body).to include("Environment")
    expect(response.body).to include(Rails.env.to_s.titleize)
    expect(response.body).to include("Last checked:")
    expect(health_page_text).not_to include("Service Degraded")
    expect(health_page_text).not_to include("DATABASE_URL")
    expect(health_page_text).not_to include("RESEND_API_KEY")
    expect(health_page_text).not_to include("password")
    expect(health_page_text).not_to include("smtp")
  end

  it "does not require authentication for the health dashboard" do
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_session_path)
  end

  it "returns a degraded dashboard when the database check fails" do
    allow(ActiveRecord::Base.connection).to receive(:select_value).and_call_original
    allow(ActiveRecord::Base.connection).to receive(:select_value)
      .with("SELECT 1")
      .and_raise(ActiveRecord::ConnectionNotEstablished.new("simulated outage"))

    get "/health"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("System Health")
    expect(response.body).to include("Service Degraded")
    expect(response.body).to include("Application")
    expect(response.body).to include("Healthy")
    expect(response.body).to include("PostgreSQL Database")
    expect(response.body).to include("Down")
    expect(health_page_text).not_to include("All Systems Operational")
    expect(health_page_text).not_to include("ActiveRecord::ConnectionNotEstablished")
    expect(health_page_text).not_to include("simulated outage")
    expect(health_page_text).not_to include("SELECT 1")
    expect(health_page_text).not_to include("DATABASE_URL")
  end

  it "returns plain-text OK for the liveness endpoint without a database query" do
    sql_events = []
    callback = ->(*) { sql_events << true }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/health/live"
    end

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("text/plain")
    expect(response.body).to eq("OK")
    expect(response).not_to redirect_to(new_session_path)
    expect(sql_events).to be_empty
  end
end
