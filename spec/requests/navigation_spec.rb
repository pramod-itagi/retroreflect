require "rails_helper"

RSpec.describe "Multi-step back navigation", type: :request do
  def back_link_on_page
    response.parsed_body.css("a").find { |anchor| anchor.text.strip.start_with?("Back to") }
  end

  it "returns from new-team and new-retrospective forms without creating records" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)

    get new_facilitator_team_path
    expect(back_link_on_page.text).to eq("Back to teams")
    expect(back_link_on_page["href"]).to eq(facilitator_teams_path)

    get facilitator_teams_path
    expect(Team.count).to eq(1)

    get new_facilitator_team_retrospective_path(team)
    expect(back_link_on_page.text).to eq("Back to #{team.name}")
    expect(back_link_on_page["href"]).to eq(facilitator_team_path(team))

    get facilitator_team_path(team)
    expect(team.retrospectives).to be_empty
    expect(response.body).to include("New retrospective")
  end

  it "keeps a draft retrospective when the facilitator goes back to the team" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])

    sign_in(facilitator)
    post facilitator_team_retrospectives_path(team), params: {
      retrospective: { title: "Sprint 12 retro", sprint_label: "Sprint 12" },
      participant_ids: [alice.id]
    }
    retro = team.retrospectives.find_by!(title: "Sprint 12 retro")

    get facilitator_retrospective_path(retro)
    expect(back_link_on_page.text).to eq("Back to #{team.name}")
    expect(back_link_on_page["href"]).to eq(facilitator_team_path(team))

    get facilitator_team_path(team)
    expect(team.retrospectives.reload).to contain_exactly(retro)
    expect(retro.reload).to be_draft
    expect(retro.participations.map(&:user)).to contain_exactly(alice)
    expect(response.body).to include("Sprint 12 retro")
    expect(response.body).not_to include("New retrospective")
  end

  it "returns from the meeting board to the retrospective without changing saved notes" do
    facilitator = create_user(name: "Jordan Facilitator")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12 retro", sprint_label: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "The pipeline was stable")
    participation.update!(submitted_at: Time.current)
    Retrospectives::Reveal.new(retro).call

    sign_in(facilitator)
    get facilitator_retrospective_meeting_path(retro)
    expect(back_link_on_page.text).to eq("Back to Sprint 12 retro")
    expect(back_link_on_page["href"]).to eq(facilitator_retrospective_path(retro))

    get facilitator_retrospective_path(retro)
    expect(retro.reload).to be_discussing
    expect(retro.feedback_items.pluck(:body)).to contain_exactly("The pipeline was stable")
  end

  it "returns from participant notes to home without discarding saved drafts" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12 retro", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Standups were focused")

    sign_in(alice)
    get participant_retrospective_path(retro)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Back to home")
    expect(response.parsed_body.at_css("header nav").text).to include("Home")

    get root_path
    expect(participation.feedback_drafts.reload.pluck(:body)).to contain_exactly("Standups were focused")
    expect(participation.reload).not_to be_submitted
  end
end
