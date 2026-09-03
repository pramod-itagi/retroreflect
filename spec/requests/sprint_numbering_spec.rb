require "rails_helper"

RSpec.describe "Automatic sprint numbering and titles", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def create_via_http(team)
    post facilitator_team_retrospectives_path(team)
    team.retrospectives.order(:id).last
  end

  it "creates the first sprint as Sprint 1 with a generated title" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      get new_facilitator_team_retrospective_path(team)
      expect(response.body).to include("Sprint 1 (2026)")
      expect(response.body).to include("Sprint 1 Retrospective - 2026")
      expect(response.body).not_to include('name="retrospective[title]"')
      expect(response.body).not_to include('name="retrospective[sprint_number]"')
      expect(response.body).not_to include("<select")

      retro = create_via_http(team)
      expect(response).to redirect_to(facilitator_retrospective_path(retro))
      expect(retro.sprint_number).to eq(1)
      expect(retro.sprint_year).to eq(2026)
      expect(retro.sprint_label).to eq("Sprint 1 (2026)")
      expect(retro.title).to eq("Sprint 1 Retrospective - 2026")
    end
  end

  it "ignores client-supplied sprint number, year, and title" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      post facilitator_team_retrospectives_path(team), params: {
        retrospective: {
          title: "My Random Retrospective",
          sprint_label: "Sprint 40",
          sprint_number: 40,
          sprint_year: 1999
        }
      }

      retro = team.retrospectives.order(:id).last
      expect(retro.sprint_number).to eq(1)
      expect(retro.sprint_year).to eq(2026)
      expect(retro.sprint_label).to eq("Sprint 1 (2026)")
      expect(retro.title).to eq("Sprint 1 Retrospective - 2026")
      expect(team.retrospectives.where(sprint_number: 40)).to be_empty
      expect(team.retrospectives.where(title: "My Random Retrospective")).to be_empty
    end
  end

  it "advances the sequence after a retrospective is closed" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      first = create_via_http(team)
      first.update!(status: :closed, closed_at: Time.current)

      second = create_via_http(team)
      expect(second.sprint_number).to eq(2)
      expect(second.sprint_year).to eq(2026)
      expect(second.title).to eq("Sprint 2 Retrospective - 2026")
      expect(first.reload.sprint_number).to eq(1)
      expect(team.retrospectives.where(sprint_number: 1).count).to eq(1)
    end
  end

  it "advances the sequence after a retrospective is cancelled and does not reuse the number" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      first = create_via_http(team)
      post cancel_facilitator_retrospective_path(first), params: {
        cancellation_reason: "Sprint planning was postponed."
      }

      second = create_via_http(team)
      expect(first.reload).to be_cancelled
      expect(second.sprint_number).to eq(2)
      expect(second.title).to eq("Sprint 2 Retrospective - 2026")
      expect(team.retrospectives.pluck(:sprint_number)).to contain_exactly(1, 2)
    end
  end

  it "keeps sprint numbering independent per team" do
    travel_to Time.zone.local(2026, 6, 15) do
      jordan = create_user(name: "Jordan")
      morgan = create_user(name: "Morgan")
      platform = create_team_with_roles(facilitator: jordan, name: "Platform")
      growth = create_team_with_roles(facilitator: morgan, name: "Growth")

      sign_in(jordan)
      platform_first = create_via_http(platform)
      platform_first.update!(status: :closed, closed_at: Time.current)
      platform_second = create_via_http(platform)

      sign_in(morgan)
      growth_first = create_via_http(growth)

      expect(platform_second.sprint_number).to eq(2)
      expect(growth_first.sprint_number).to eq(1)
      expect(growth_first.title).to eq("Sprint 1 Retrospective - 2026")
    end
  end

  it "keeps the one-running-retrospective rule while numbering sprints" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      first = create_via_http(team)
      post facilitator_team_retrospectives_path(team), params: {
        retrospective: { title: "Sprint 2", sprint_number: 2 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(team.retrospectives.running.count).to eq(1)
      expect(team.retrospectives.count).to eq(1)
      expect(first.reload.sprint_number).to eq(1)
    end
  end

  it "does not reset the sprint number when the calendar year changes" do
    facilitator = create_user(name: "Jordan")
    team = create_team_with_roles(facilitator: facilitator)

    travel_to Time.zone.local(2026, 6, 15) do
      sign_in(facilitator)
      first = create_via_http(team)
      first.update!(status: :closed, closed_at: Time.current)
      second = create_via_http(team)
      second.update!(status: :closed, closed_at: Time.current)
      expect(first.sprint_label).to eq("Sprint 1 (2026)")
      expect(second.sprint_label).to eq("Sprint 2 (2026)")
    end

    travel_to Time.zone.local(2027, 1, 10) do
      sign_in(facilitator)
      third = create_via_http(team)

      expect(third.sprint_number).to eq(3)
      expect(third.sprint_year).to eq(2027)
      expect(third.sprint_label).to eq("Sprint 3 (2027)")
      expect(third.title).to eq("Sprint 3 Retrospective - 2027")

      historical = team.retrospectives.find_by!(sprint_number: 2)
      expect(historical.sprint_label).to eq("Sprint 2 (2026)")
      expect(historical.sprint_year).to eq(2026)
      expect(historical.title).to eq("Sprint 2 Retrospective - 2026")

      get facilitator_retrospective_path(historical)
      expect(response.body).to include("Sprint 2 (2026)")
      expect(response.body).to include("Sprint 2 Retrospective - 2026")
      expect(response.body).not_to include("Sprint 2 Retrospective - 2027")
    end
  end

  it "does not rewrite historical titles or sprint labels" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)
      historical = team.retrospectives.create!(
        title: "Testing reprospective",
        sprint_label: "Sprint 12",
        created_by: facilitator,
        status: :closed,
        closed_at: Time.current
      )

      sign_in(facilitator)
      created = create_via_http(team)

      expect(created.sprint_number).to eq(13)
      expect(created.title).to eq("Sprint 13 Retrospective - 2026")
      expect(historical.reload.title).to eq("Testing reprospective")
      expect(historical.sprint_label).to eq("Sprint 12")
      expect(historical.sprint_number).to be_nil
    end
  end

  it "keeps generated title aligned with the assigned sprint number and year" do
    travel_to Time.zone.local(2026, 6, 15) do
      facilitator = create_user(name: "Jordan")
      team = create_team_with_roles(facilitator: facilitator)

      sign_in(facilitator)
      retro = create_via_http(team)

      expect(retro.title).to eq(Retrospective.generated_title(retro.sprint_number, retro.sprint_year))
      expect(retro.sprint_label).to eq(Retrospective.sprint_identifier(retro.sprint_number, retro.sprint_year))
    end
  end
end
