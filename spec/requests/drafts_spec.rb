require "rails_helper"

RSpec.describe "Participant feedback", type: :request do
  def collecting_setup
    facilitator = create_user(name: "Jordan Facilitator")
    alice = create_user(name: "Alice Example")
    bob = create_user(name: "Bob Example")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob])
    retro = team.retrospectives.create!(title: "Retro", sprint_label: "Sprint 12", created_by: facilitator)
    alice_participation = retro.participations.create!(user: alice)
    bob_participation = retro.participations.create!(user: bob)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    {
      facilitator: facilitator,
      alice: alice,
      bob: bob,
      team: team,
      retro: retro,
      alice_participation: alice_participation,
      bob_participation: bob_participation
    }
  end

  it "shows the sprint and four categories, and lets a participant save multiple draft points" do
    setup = collecting_setup

    sign_in(setup[:alice])
    get participant_retrospective_path(setup[:retro])

    expect(response).to have_http_status(:ok)
    page = CGI.unescapeHTML(response.body)
    expect(page).to include("Sprint 12")
    expect(page).to include("What went well")
    expect(page).to include("What didn't go well")
    expect(page).to include("What to continue")
    expect(page).to include("What to improve")
    expect(page).to include("Add a point")
    expect(page).to include("Add another point")
    expect(page).to include("Your feedback is anonymous. The facilitator can see whether you've submitted, but not who wrote each point.")
    expect(page).not_to include("Back to home")
    save_buttons = response.parsed_body.css("input[type=submit], button[type=submit]").select do |element|
      (element["value"] || element.text).strip == "Save draft"
    end
    expect(save_buttons.size).to eq(1)
    expect(response.parsed_body.at_css("header nav").text).to include("Home")
    expect(response.parsed_body.at("h1").text).to eq("Retro")
    meta = response.parsed_body.at(".session-meta").text.gsub(/\s+/, " ").strip
    expect(meta).to include("Platform")
    expect(meta).to include("Sprint 12")
    expect(meta).to include("Draft")

    post save_participant_retrospective_drafts_path(setup[:retro]), params: {
      new_drafts: {
        went_well: "Standups were focused",
        did_not_go_well: "",
        continue: "",
        improve: ""
      }
    }
    post save_participant_retrospective_drafts_path(setup[:retro]), params: {
      new_drafts: { went_well: "The pipeline was stable" }
    }

    drafts = setup[:alice_participation].feedback_drafts.where(category: :went_well)
    expect(drafts.count).to eq(2)
    expect(setup[:alice_participation].reload).not_to be_submitted
    expect(setup[:retro].feedback_items).to be_empty
  end

  it "lets a participant edit their own draft before submitting" do
    setup = collecting_setup
    draft = setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :improve,
      body: "Original point"
    )

    sign_in(setup[:alice])
    patch participant_retrospective_draft_path(setup[:retro], draft), params: {
      feedback_draft: { category: "improve", body: "Edited point" }
    }

    expect(draft.reload.body).to eq("Edited point")
    expect(setup[:alice_participation].reload).not_to be_submitted
  end

  it "saves existing and new points with one Save Draft action" do
    setup = collecting_setup
    draft = setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Original point"
    )

    sign_in(setup[:alice])
    post save_participant_retrospective_drafts_path(setup[:retro]), params: {
      drafts: { draft.id.to_s => { body: "Edited point" } },
      new_drafts: { improve: "Handoffs still take too long" }
    }

    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))
    follow_redirect!
    expect(response.body).to include("Draft saved.")
    expect(draft.reload.body).to eq("Edited point")
    expect(setup[:alice_participation].feedback_drafts.pluck(:body)).to contain_exactly(
      "Edited point",
      "Handoffs still take too long"
    )
  end

  it "saves several new points in one category from a single Save Draft" do
    setup = collecting_setup

    sign_in(setup[:alice])
    get participant_retrospective_path(setup[:retro])
    expect(response.body).to include('data-controller="add-points"')
    expect(response.body).to include("Add another point")

    post save_participant_retrospective_drafts_path(setup[:retro]), params: {
      new_drafts: {
        went_well: [
          "Deployment went smoothly",
          "",
          "Communication between teams was good",
          "   ",
          "Testing was completed on time"
        ],
        improve: ["Handoffs still take too long", ""]
      }
    }

    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))
    expect(setup[:alice_participation].feedback_drafts.where(category: :went_well).pluck(:body)).to contain_exactly(
      "Deployment went smoothly",
      "Communication between teams was good",
      "Testing was completed on time"
    )
    expect(setup[:alice_participation].feedback_drafts.where(category: :improve).pluck(:body)).to contain_exactly(
      "Handoffs still take too long"
    )
    expect(setup[:alice_participation].feedback_drafts.count).to eq(4)
    expect(setup[:alice_participation].reload).not_to be_submitted
  end

  it "lets a participant remove their own draft before submitting" do
    setup = collecting_setup
    draft = setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Remove this point"
    )

    sign_in(setup[:alice])
    delete participant_retrospective_draft_path(setup[:retro], draft)

    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))
    expect(setup[:alice_participation].feedback_drafts.reload).to be_empty
    expect(setup[:alice_participation].reload).not_to be_submitted
  end

  it "does not show another participant's notes or identity" do
    setup = collecting_setup
    setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Alice secret note"
    )

    sign_in(setup[:bob])
    get participant_retrospective_path(setup[:retro])

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Alice secret note")
    expect(response.body).not_to include("Alice Example")
    expect(response.body).not_to include(setup[:alice].email)
  end

  it "does not let a participant edit someone else's draft" do
    setup = collecting_setup
    draft = setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Alice secret note"
    )

    sign_in(setup[:bob])
    patch participant_retrospective_draft_path(setup[:retro], draft), params: {
      feedback_draft: { category: "went_well", body: "Bob overwrite" }
    }

    expect(response).to redirect_to(root_path)
    expect(draft.reload.body).to eq("Alice secret note")
  end

  it "does not let a facilitator read draft bodies" do
    setup = collecting_setup
    setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Alice secret note"
    )

    sign_in(setup[:facilitator])
    get participant_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)

    get facilitator_retrospective_path(setup[:retro])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Not submitted")
    expect(response.body).not_to include("Alice secret note")
  end

  it "tracks submission status and locks edits afterward" do
    setup = collecting_setup
    draft = setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Standups were focused"
    )

    sign_in(setup[:alice])
    post participant_retrospective_submission_path(setup[:retro])

    expect(setup[:alice_participation].reload).to be_submitted
    expect(setup[:alice_participation].response_status_label).to eq("Submitted")

    get participant_retrospective_path(setup[:retro])
    expect(response.body).not_to include("Save draft")
    expect(response.body).not_to include("Submit feedback")
    expect(response.body).to include("Submitted")

    post save_participant_retrospective_drafts_path(setup[:retro]), params: {
      drafts: { draft.id.to_s => { body: "Changed after submit" } },
      new_drafts: { improve: "Too late from bulk save" }
    }
    expect(response).to redirect_to(root_path)
    expect(draft.reload.body).to eq("Standups were focused")

    patch participant_retrospective_draft_path(setup[:retro], draft), params: {
      feedback_draft: { category: "went_well", body: "Changed after submit" }
    }
    expect(response).to redirect_to(root_path)
    expect(draft.reload.body).to eq("Standups were focused")

    post participant_retrospective_drafts_path(setup[:retro]), params: {
      feedback_draft: { category: "improve", body: "Too late" }
    }
    expect(setup[:alice_participation].feedback_drafts.count).to eq(1)

    get new_participant_retrospective_submission_path(setup[:retro])
    expect(response).to redirect_to(root_path)

    sign_in(setup[:facilitator])
    get facilitator_retrospective_path(setup[:retro])
    expect(response.body).to include("Submitted")
    expect(response.body).not_to include("Standups were focused")
  end

  it "does not let an uninvited user write notes" do
    setup = collecting_setup
    outsider = create_user(name: "Outsider")

    sign_in(outsider)
    post participant_retrospective_drafts_path(setup[:retro]), params: {
      feedback_draft: { category: "went_well", body: "Should not save" }
    }

    expect(response).to redirect_to(root_path)
    expect(setup[:retro].feedback_drafts).to be_empty
  end

  it "does not allow notes after collecting ends" do
    setup = collecting_setup
    setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Before reveal"
    )
    setup[:alice_participation].update!(submitted_at: Time.current)
    Retrospectives::Reveal.new(setup[:retro]).call

    sign_in(setup[:alice])
    get participant_retrospective_path(setup[:retro])
    expect(response).to redirect_to(root_path)

    post participant_retrospective_drafts_path(setup[:retro]), params: {
      feedback_draft: { category: "improve", body: "After reveal" }
    }
    expect(response).to redirect_to(root_path)
    expect(FeedbackDraft.where(retrospective: setup[:retro])).to be_empty
    expect(setup[:retro].feedback_items.pluck(:body)).to eq(["Before reveal"])
    expect(FeedbackItem.column_names).not_to include("user_id")
  end

  it "asks for confirmation before submitting and leaves drafts unchanged on cancel" do
    setup = collecting_setup
    setup[:alice_participation].feedback_drafts.create!(
      retrospective: setup[:retro],
      category: :went_well,
      body: "Standups were focused"
    )

    sign_in(setup[:alice])
    get participant_retrospective_path(setup[:retro])
    page = CGI.unescapeHTML(response.body)
    expect(page).to include("Submit feedback")
    expect(page).to include("Submit your feedback?")
    expect(page).to include("Once submitted, you won't be able to edit your feedback.")
    expect(page).to include(participant_retrospective_submission_path(setup[:retro]))
    expect(page).not_to include(new_participant_retrospective_submission_path(setup[:retro]))

    get new_participant_retrospective_submission_path(setup[:retro])
    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))

    get participant_retrospective_path(setup[:retro])
    expect(setup[:alice_participation].reload).not_to be_submitted
    expect(setup[:alice_participation].feedback_drafts.pluck(:body)).to contain_exactly("Standups were focused")

    post participant_retrospective_submission_path(setup[:retro])
    expect(setup[:alice_participation].reload).to be_submitted
  end
end
