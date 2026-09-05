require "rails_helper"

RSpec.describe "Retrospective reveal", type: :request do
  def collecting_setup(participant_count: 10)
    facilitator = create_user(name: "Facilitator")
    members = Array.new(participant_count) { |index| create_user(name: "Member #{index}") }
    team = create_team_with_roles(facilitator: facilitator, members: members)
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participations = members.map { |member| retro.participations.create!(user: member) }
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    {
      facilitator: facilitator,
      members: members,
      team: team,
      retro: retro,
      participations: participations
    }
  end

  def submit!(participation, body:)
    participation.feedback_drafts.create!(
      retrospective: participation.retrospective,
      category: :went_well,
      body: body
    )
    participation.update!(submitted_at: Time.current)
  end

  def reveal_button(html = response.parsed_body)
    html.at_css("form[action$='/reveal'] input[type=submit], form[action$='/reveal'] button")
  end

  it "rejects reveal when zero participants have submitted, including draft-only notes" do
    setup = collecting_setup
    setup[:participations].first.feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Only a draft"
    )

    sign_in(setup[:facilitator])
    get facilitator_retrospective_path(setup[:retro])
    expect(response.body).to include("0 of 10 participants have submitted feedback.")
    expect(reveal_button["disabled"]).to be_present
    tooltip = response.parsed_body.at_css("[role='tooltip']")
    expect(tooltip.text).to include("Reveal will be enabled after at least one participant submits feedback.")
    expect(response.body).not_to include("<p class=\"mt-3 max-w-xs")

    post reveal_facilitator_retrospective_path(setup[:retro])
    expect(response).to redirect_to(facilitator_retrospective_path(setup[:retro]))
    follow_redirect!
    expect(response.body).to include(Retrospectives::Reveal::NO_SUBMISSIONS_MESSAGE)

    setup[:retro].reload
    expect(setup[:retro]).to be_collecting
    expect(setup[:retro].feedback_items).to be_empty
    expect(setup[:retro].feedback_drafts.pluck(:body)).to contain_exactly("Only a draft")
  end

  it "lets the facilitator reveal after one participant submits" do
    setup = collecting_setup
    submit!(setup[:participations].first, body: "One submitted note")

    sign_in(setup[:facilitator])
    get facilitator_retrospective_path(setup[:retro])
    expect(response.body).to include("1 of 10 participants have submitted feedback.")
    expect(reveal_button["disabled"]).to be_blank
    expect(response.body).not_to include("Reveal will be enabled after at least one participant submits feedback.")

    post reveal_facilitator_retrospective_path(setup[:retro])
    expect(response).to redirect_to(facilitator_retrospective_meeting_path(setup[:retro]))

    setup[:retro].reload
    expect(setup[:retro]).to be_discussing
    expect(setup[:retro].feedback_items.pluck(:body)).to contain_exactly("One submitted note")
    expect(FeedbackItem.column_names).not_to include("user_id", "participation_id")
  end

  it "reveals a submitted draft and keeps an unsubmitted draft off the board" do
    setup = collecting_setup(participant_count: 2)
    submitted = setup[:participations].first
    unsubmitted = setup[:participations].last
    submit!(submitted, body: "Ready to publish")
    unsubmitted.feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :improve,
      body: "Still private"
    )

    sign_in(setup[:facilitator])
    post reveal_facilitator_retrospective_path(setup[:retro])

    setup[:retro].reload
    expect(setup[:retro]).to be_discussing
    expect(setup[:retro].feedback_items.pluck(:body)).to contain_exactly("Ready to publish")
    expect(setup[:retro].feedback_items.pluck(:body)).not_to include("Still private")
    expect(setup[:retro].feedback_drafts).to be_empty
  end

  it "reveals only submitted feedback when a retrospective has both submitted and unsubmitted drafts" do
    setup = collecting_setup(participant_count: 3)
    first, second, third = setup[:participations]
    submit!(first, body: "Submitted note A")
    submit!(second, body: "Submitted note B")
    third.feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :improve,
      body: "Private unsubmitted draft"
    )

    sign_in(setup[:facilitator])
    post reveal_facilitator_retrospective_path(setup[:retro])

    setup[:retro].reload
    expect(setup[:retro]).to be_discussing
    expect(setup[:retro].feedback_items.pluck(:body)).to contain_exactly("Submitted note A", "Submitted note B")
    expect(setup[:retro].feedback_items.pluck(:body)).not_to include("Private unsubmitted draft")
    expect(FeedbackItem.column_names).not_to include("user_id", "participation_id")
  end

  it "lets the facilitator reveal with partial submissions" do
    setup = collecting_setup
    setup[:participations].first(5).each_with_index do |participation, index|
      submit!(participation, body: "Submitted note #{index}")
    end

    sign_in(setup[:facilitator])
    get facilitator_retrospective_path(setup[:retro])
    expect(response.body).to include("5 of 10 participants have submitted feedback.")
    expect(reveal_button["disabled"]).to be_blank

    post reveal_facilitator_retrospective_path(setup[:retro])
    setup[:retro].reload
    expect(setup[:retro]).to be_discussing
    expect(setup[:retro].feedback_items.pluck(:body)).to match_array((0..4).map { |index| "Submitted note #{index}" })
  end

  it "lets the facilitator reveal when every participant has submitted" do
    setup = collecting_setup
    setup[:participations].each_with_index do |participation, index|
      submit!(participation, body: "All in #{index}")
    end

    sign_in(setup[:facilitator])
    get facilitator_retrospective_path(setup[:retro])
    expect(response.body).to include("10 of 10 participants have submitted feedback.")
    expect(reveal_button["disabled"]).to be_blank

    post reveal_facilitator_retrospective_path(setup[:retro])
    setup[:retro].reload
    expect(setup[:retro]).to be_discussing
    expect(setup[:retro].feedback_items.count).to eq(10)
  end

  it "still lets the facilitator cancel a collecting retrospective with zero submissions" do
    setup = collecting_setup
    setup[:participations].first.feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Will not be published"
    )

    sign_in(setup[:facilitator])
    post cancel_facilitator_retrospective_path(setup[:retro])

    setup[:retro].reload
    expect(response).to redirect_to(facilitator_retrospective_path(setup[:retro]))
    expect(setup[:retro]).to be_cancelled
    expect(setup[:retro].feedback_items).to be_empty
    expect(FeedbackItem.where(retrospective: setup[:retro])).to be_empty
  end
end
