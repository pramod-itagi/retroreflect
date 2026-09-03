require "rails_helper"

RSpec.describe "Operation error handling", type: :request do
  def page_text
    CGI.unescapeHTML(response.body)
  end

  def turbo_headers(referer)
    {
      "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
      "HTTP_REFERER" => referer
    }
  end

  it "keeps a member on the team and shows an alert when remove fails unexpectedly" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    membership = team.memberships.find_by!(user: alice)

    allow_any_instance_of(Membership).to receive(:destroy).and_raise(RuntimeError, "secret boom PG::UndefinedTable")

    sign_in(facilitator)
    delete facilitator_team_membership_path(team, membership),
           headers: { "HTTP_REFERER" => facilitator_team_path(team) }

    expect(response).to redirect_to(facilitator_team_path(team))
    expect(flash[:alert]).to eq("We couldn't remove Alice from the team. Please try again.")
    expect(membership.reload).to be_present
    follow_redirect!
    expect(page_text).to include("We couldn't remove Alice from the team. Please try again.")
    expect(response.body).to include("app-alert-error")
    expect(page_text).not_to include("secret boom")
    expect(page_text).not_to include("PG::UndefinedTable")
  end

  it "renders an in-page turbo alert instead of the 500 page for a failed mutation" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    membership = team.memberships.find_by!(user: alice)

    allow_any_instance_of(Membership).to receive(:destroy).and_raise(RuntimeError, "secret boom")

    sign_in(facilitator)
    delete facilitator_team_membership_path(team, membership),
           headers: turbo_headers(facilitator_team_path(team))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("app-alerts")
    expect(page_text).to include("Something went wrong")
    expect(page_text).to include("We couldn't remove Alice from the team. Please try again.")
    expect(response.body).to include("app-alert-error")
    expect(page_text).not_to include("secret boom")
    expect(page_text).not_to include("We couldn't find that page.")
    expect(membership.reload).to be_present
  end

  it "keeps submitted action item fields available after a validation failure over turbo" do
    facilitator = create_user(name: "Jordan")
    owner = create_user(name: "Owner")
    team = create_team_with_roles(facilitator: facilitator, members: [owner])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator, status: :discussing)

    sign_in(facilitator)
    post facilitator_retrospective_action_items_path(retro),
         params: { action_item: { title: "", owner_id: owner.id, due_on: Date.current + 3, status: "open" } },
         headers: turbo_headers(facilitator_retrospective_meeting_path(retro))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(page_text).to include("Title can't be blank")
    expect(page_text).not_to include("Something went wrong")
    expect(team.action_items.where(title: "")).to be_empty
  end

  it "keeps feedback on the page when submit fails unexpectedly over turbo" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Retro", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Standups were focused")

    allow_any_instance_of(Participation).to receive(:submit_responses).and_raise(RuntimeError, "secret boom")

    sign_in(alice)
    post participant_retrospective_submission_path(retro),
         headers: turbo_headers(participant_retrospective_path(retro))

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("We couldn't submit your feedback. Please try again.")
    expect(page_text).not_to include("secret boom")
    expect(participation.reload).not_to be_submitted
    expect(participation.feedback_drafts.pluck(:body)).to contain_exactly("Standups were focused")
  end

  it "marks mutation buttons with a loading label" do
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    create_user(name: "Morgan")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])

    sign_in(facilitator)
    get facilitator_team_path(team)

    expect(response.body).to include('data-turbo-submits-with="Updating..."')
    expect(response.body).to include('data-turbo-submits-with="Removing..."')
    expect(response.body).to include('data-confirm-busy="Removing..."')
    expect(response.body).to include('data-turbo-submits-with="Adding..."')
  end
end
