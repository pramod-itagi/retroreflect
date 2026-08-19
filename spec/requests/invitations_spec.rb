require "rails_helper"

RSpec.describe "Invitation access", type: :request do
  include ActiveJob::TestHelper

  def invited_setup
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    bob = create_user(name: "Bob")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    { facilitator: facilitator, alice: alice, bob: bob, team: team, retro: retro, participation: participation }
  end

  def issue_invitation!(participation, invited_at: Time.current)
    raw, digest = Token.generate
    participation.update!(invitation_token_digest: digest, invited_at: invited_at)
    raw
  end

  it "emails each selected participant when the facilitator sends invitations" do
    setup = invited_setup
    setup[:retro].participations.create!(user: setup[:bob])

    sign_in(setup[:facilitator])
    expect do
      post start_collecting_facilitator_retrospective_path(setup[:retro])
    end.to have_enqueued_job(SendRetroInvitationJob).exactly(2).times

    expect(setup[:retro].reload).to be_collecting
    expect(setup[:participation].reload.invitation_status_label).to eq("Invited")

    perform_enqueued_jobs
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.map(&:to).flatten).to contain_exactly(setup[:alice].email, setup[:bob].email)
    expect(ActionMailer::Base.deliveries.last.body.encoded).to include("/invitations/")
  end

  it "lets the invited user open the retrospective" do
    setup = invited_setup
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(setup[:participation])

    sign_in(setup[:alice])
    get invitation_path(token: raw)

    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))
    follow_redirect!
    expect(response.body).to include("Invitation accepted")
    expect(setup[:participation].reload).to be_invitation_accepted
    expect(setup[:participation].invitation_status_label).to eq("Opened")
  end

  it "rejects an invalid invitation token" do
    sign_in(create_user(name: "Alice"))
    get invitation_path(token: "not-a-real-token")

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Invitation is invalid")
  end

  it "rejects an expired invitation" do
    setup = invited_setup
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(setup[:participation], invited_at: 15.days.ago)

    sign_in(setup[:alice])
    get invitation_path(token: raw)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Invitation has expired")
    expect(setup[:participation].reload).not_to be_invitation_accepted
  end

  it "denies a forwarded invitation used by a different account" do
    setup = invited_setup
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(setup[:participation])

    sign_in(setup[:bob])
    get invitation_path(token: raw)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("This invitation is for a different account")
    expect(setup[:participation].reload).not_to be_invitation_accepted
  end

  it "does not let an uninvited participant open the retrospective" do
    setup = invited_setup
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)

    sign_in(setup[:bob])
    get participant_retrospective_path(setup[:retro])

    expect(response).to redirect_to(root_path)
  end

  it "does not add the same participant twice" do
    setup = invited_setup

    sign_in(setup[:facilitator])
    post facilitator_retrospective_participations_path(setup[:retro]), params: { user_id: setup[:alice].id }

    expect(response).to redirect_to(facilitator_retrospective_path(setup[:retro]))
    follow_redirect!
    expect(response.body).to include("has already been taken")
    expect(setup[:retro].participations.where(user: setup[:alice]).count).to eq(1)
  end

  it "does not send duplicate invitations after collecting has started" do
    setup = invited_setup

    sign_in(setup[:facilitator])
    post start_collecting_facilitator_retrospective_path(setup[:retro])
    expect(SendRetroInvitationJob).to have_been_enqueued.once

    expect do
      post start_collecting_facilitator_retrospective_path(setup[:retro])
    end.not_to have_enqueued_job(SendRetroInvitationJob)

    expect(setup[:retro].reload).to be_collecting
    expect(setup[:participation].reload.invited_at).to be_present
  end

  it "lets the invited user reuse their own accepted invitation while collecting is open" do
    setup = invited_setup
    setup[:retro].update!(status: :collecting, collecting_started_at: Time.current)
    raw = issue_invitation!(setup[:participation])

    sign_in(setup[:alice])
    get invitation_path(token: raw)
    accepted_at = setup[:participation].reload.accessed_at

    get invitation_path(token: raw)
    expect(response).to redirect_to(participant_retrospective_path(setup[:retro]))
    follow_redirect!
    expect(response.body).to include("You already accepted this invitation")
    expect(setup[:participation].reload.accessed_at).to eq(accepted_at)
  end

  it "rejects an invitation after the retrospective is no longer open" do
    setup = invited_setup
    raw = issue_invitation!(setup[:participation])
    setup[:retro].update!(status: :discussing, collecting_started_at: Time.current, revealed_at: Time.current)

    sign_in(setup[:alice])
    get invitation_path(token: raw)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("This retrospective is no longer open")
  end
end
