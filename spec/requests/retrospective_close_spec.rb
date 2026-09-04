require "rails_helper"

RSpec.describe "Retrospective close", type: :request do
  def setup_discussing
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(
      title: "Sprint 1 Retrospective - 2026",
      sprint_label: "Sprint 1 (2026)",
      sprint_number: 1,
      sprint_year: 2026,
      created_by: facilitator
    )
    retro.participations.create!(user: alice)
    retro.update!(
      status: :discussing,
      collecting_started_at: Time.current,
      revealed_at: Time.current
    )
    { facilitator: facilitator, alice: alice, team: team, retro: retro }
  end

  def close_form(path)
    response.parsed_body.at_css("form[action='#{path}']")
  end

  it "asks for confirmation before closing from the retrospective and meeting pages" do
    data = setup_discussing
    path = close_facilitator_retrospective_path(data[:retro])

    sign_in(data[:facilitator])
    get facilitator_retrospective_path(data[:retro])
    form = close_form(path)
    expect(form).to be_present
    expect(form["data-turbo-confirm"]).to eq("Close #{data[:retro].title}?")
    expect(form["data-confirm-description"]).to include(data[:team].name)
    expect(form["data-confirm-accept"]).to eq("Close retrospective")
    expect(form["data-confirm-cancel"]).to eq("Keep retrospective")
    expect(form["data-confirm-variant"]).to be_blank
    expect(form.at_css("[type='submit']")["class"]).to include("home-action-danger")
    expect(form.at_css("[type='submit']")["class"]).not_to include("home-action-danger-solid")
    expect(form.at_css("[type='submit']")["class"]).not_to include("home-action-primary")
    expect(response.body).to include("Meeting board")

    get facilitator_retrospective_meeting_path(data[:retro])
    meeting_form = close_form(path)
    expect(meeting_form).to be_present
    expect(meeting_form["data-turbo-confirm"]).to eq("Close #{data[:retro].title}?")
    expect(meeting_form.at_css("[type='submit']")["class"]).to include("home-action-danger")
    expect(data[:retro].reload).to be_discussing
  end

  it "closes the retrospective when the facilitator confirms" do
    data = setup_discussing

    sign_in(data[:facilitator])
    post close_facilitator_retrospective_path(data[:retro])

    expect(response).to redirect_to(facilitator_retrospective_path(data[:retro]))
    expect(data[:retro].reload).to be_closed
    expect(data[:retro].closed_at).to be_present
  end

  it "does not close when the page is only viewed" do
    data = setup_discussing

    sign_in(data[:facilitator])
    get facilitator_retrospective_path(data[:retro])
    get facilitator_retrospective_meeting_path(data[:retro])

    expect(data[:retro].reload).to be_discussing
    expect(data[:retro].closed_at).to be_nil
  end

  it "does not let an unauthorized user close a retrospective" do
    data = setup_discussing

    sign_in(data[:alice])
    post close_facilitator_retrospective_path(data[:retro])

    expect(response).to redirect_to(root_path)
    expect(data[:retro].reload).to be_discussing
  end
end
