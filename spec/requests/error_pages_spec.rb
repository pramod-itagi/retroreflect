require "rails_helper"

RSpec.describe "Error pages", type: :request do
  def page_heading
    response.parsed_body.at("h1")&.text
  end

  def page_lede
    response.parsed_body.at(".listing-lede")&.text
  end

  it "renders a branded 404 for unknown routes" do
    get "/this-page-does-not-exist"

    expect(response).to have_http_status(:not_found)
    expect(page_heading).to eq("We couldn't find that page.")
    expect(page_lede).to eq("The page you're looking for doesn't exist or may have been moved.")
    expect(response.body).to include("Back to home")
    expect(response.body).to include("Go back")
    expect(response.parsed_body.text).not_to include("ActionController::RoutingError")
  end

  it "renders a branded 404 for a missing team" do
    sign_in(create_user(name: "Jordan"))

    get facilitator_team_path(id: 999_999)

    expect(response).to have_http_status(:not_found)
    expect(page_heading).to eq("We couldn't find that page.")
    expect(response.body).to include("Back to home")
    expect(response.parsed_body.text).not_to include("ActiveRecord::RecordNotFound")
    expect(response.parsed_body.text).not_to include("Couldn't find Team")
  end

  it "renders a branded 404 for a missing retrospective" do
    sign_in(create_user(name: "Alice"))

    get participant_retrospective_path(id: 999_999)

    expect(response).to have_http_status(:not_found)
    expect(page_heading).to eq("We couldn't find that page.")
    expect(response.parsed_body.text).not_to include("Couldn't find Retrospective")
  end

  it "exposes the 404 page directly" do
    get "/404"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page not found · Retroreflect")
    expect(page_heading).to eq("We couldn't find that page.")
  end

  it "exposes the 500 page directly" do
    get "/500"

    expect(response).to have_http_status(:internal_server_error)
    expect(page_heading).to eq("Something went wrong.")
    expect(page_lede).to eq("We couldn't complete your request. Please try again.")
    expect(response.body).to include("Try again")
    expect(response.body).to include("Back to home")
    expect(response.body).not_to include("traceback")
    expect(response.body).not_to include("action_dispatch.exception")
  end

  it "keeps the health check available" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
