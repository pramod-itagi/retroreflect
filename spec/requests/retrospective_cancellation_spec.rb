require "rails_helper"

RSpec.describe "Retrospective cancellation", type: :request do
  def setup_draft
    facilitator = create_user(name: "Jordan")
    alice = create_user(name: "Alice")
    member = create_user(name: "Morgan")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(
      title: "Sprint 1 Retrospective - 2026",
      sprint_label: "Sprint 1 (2026)",
      sprint_number: 1,
      sprint_year: 2026,
      created_by: facilitator
    )
    retro.participations.create!(user: alice)
    {
      facilitator: facilitator,
      alice: alice,
      member: member,
      team: team,
      retro: retro
    }
  end

  def page_text
    CGI.unescapeHTML(response.body)
  end

  it "lets an authorized facilitator cancel a draft retrospective with a reason" do
    data = setup_draft

    sign_in(data[:facilitator])
    get facilitator_retrospective_path(data[:retro])
    expect(page_text).to include("Cancel retrospective")
    expect(page_text).to include("Cancel retrospective?")
    expect(page_text).to include("Are you sure you want to cancel this retrospective?")
    expect(page_text).to include("Reason for cancellation")
    expect(response.body).to include(cancel_facilitator_retrospective_path(data[:retro]))
    send_invitations = response.parsed_body.at_css("form[action='#{start_collecting_facilitator_retrospective_path(data[:retro])}']")
    expect(send_invitations.text).not_to include("Cancel")
    cancel_form = response.parsed_body.at_css("form[action='#{cancel_facilitator_retrospective_path(data[:retro])}']")
    expect(cancel_form).to be_present
    expect(cancel_form.at_css("textarea[name='cancellation_reason']")).to be_present
    expect(cancel_form.at_css("button[type='submit']").text).to include("Confirm")

    post cancel_facilitator_retrospective_path(data[:retro]), params: {
      cancellation_reason: "Sprint planning was postponed."
    }

    data[:retro].reload
    expect(response).to redirect_to(facilitator_retrospective_path(data[:retro]))
    expect(data[:retro]).to be_cancelled
    expect(data[:retro].cancellation_reason).to eq("Sprint planning was postponed.")
    expect(data[:retro].participations.map(&:user)).to contain_exactly(data[:alice])

    follow_redirect!
    expect(page_text).to include("This retrospective was cancelled.")
    expect(page_text).to include("Reason for cancellation")
    expect(page_text).to include("Sprint planning was postponed.")

    get retrospectives_path, params: { status: "previous" }
    expect(response.body).to include(data[:retro].title)
  end

  it "cancels without a reason when none is provided" do
    data = setup_draft

    sign_in(data[:facilitator])
    post cancel_facilitator_retrospective_path(data[:retro])

    data[:retro].reload
    expect(data[:retro]).to be_cancelled
    expect(data[:retro].cancellation_reason).to be_nil
  end

  it "does not cancel when the confirmation modal is only opened" do
    data = setup_draft

    sign_in(data[:facilitator])
    get facilitator_retrospective_path(data[:retro])
    expect(data[:retro].reload).to be_draft
    expect(data[:retro].cancelled_at).to be_nil
  end

  it "does not let an unauthorized user cancel a retrospective" do
    data = setup_draft

    sign_in(data[:alice])
    post cancel_facilitator_retrospective_path(data[:retro]), params: {
      cancellation_reason: "Should not persist"
    }

    expect(response).to redirect_to(root_path)
    expect(data[:retro].reload).to be_draft
    expect(data[:retro].cancellation_reason).to be_nil
  end

  it "does not let a second cancel request reopen or duplicate cancellation" do
    data = setup_draft

    sign_in(data[:facilitator])
    post cancel_facilitator_retrospective_path(data[:retro]), params: {
      cancellation_reason: "First cancel"
    }
    expect(data[:retro].reload).to be_cancelled

    post cancel_facilitator_retrospective_path(data[:retro]), params: {
      cancellation_reason: "Second cancel"
    }

    expect(response).to redirect_to(root_path)
    data[:retro].reload
    expect(data[:retro]).to be_cancelled
    expect(data[:retro].cancellation_reason).to eq("First cancel")
    expect(data[:team].retrospectives.cancelled.count).to eq(1)
  end

  it "keeps cancelled retrospectives in history after a new sprint is created" do
    data = setup_draft

    sign_in(data[:facilitator])
    post cancel_facilitator_retrospective_path(data[:retro]), params: {
      cancellation_reason: "Sprint planning was postponed."
    }

    post facilitator_team_retrospectives_path(data[:team])
    next_retro = data[:team].retrospectives.order(:id).last

    expect(next_retro.sprint_number).to eq(2)
    expect(data[:retro].reload).to be_cancelled
    expect(data[:retro].cancellation_reason).to eq("Sprint planning was postponed.")

    get facilitator_retrospective_path(data[:retro])
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Sprint planning was postponed.")
  end
end
