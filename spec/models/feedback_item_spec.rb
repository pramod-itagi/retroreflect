require "rails_helper"

RSpec.describe FeedbackItem do
  it "does not have author columns" do
    expect(described_class.column_names).not_to include("user_id", "participation_id", "feedback_draft_id")
  end

  it "does not associate to users, participations, or drafts" do
    names = described_class.reflect_on_all_associations.map(&:name)
    expect(names).to eq([:retrospective])
    expect(names).not_to include(:user, :participation, :feedback_draft, :author)
  end
end

RSpec.describe Retrospectives::Reveal do
  it "publishes anonymous notes and deletes drafts" do
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "The pipeline was stable")
    participation.update!(submitted_at: Time.current)

    described_class.new(retro).call

    retro.reload
    expect(retro).to be_discussing
    expect(FeedbackDraft.where(retrospective: retro)).to be_empty
    item = FeedbackItem.find_by!(retrospective: retro)
    expect(item.body).to eq("The pipeline was stable")
    expect(item.reveal_position).to eq(1)
    expect(item.attributes.keys).not_to include("user_id", "participation_id")
  end

  it "rejects reveal when nobody has submitted, even if drafts exist" do
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    draft = participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Unsubmitted draft")

    expect { described_class.new(retro).call }.to raise_error(described_class::Error, described_class::NO_SUBMISSIONS_MESSAGE)

    retro.reload
    expect(retro).to be_collecting
    expect(retro.feedback_items).to be_empty
    expect(draft.reload.body).to eq("Unsubmitted draft")
    expect(retro.revealed_at).to be_nil
  end

  it "publishes submitted drafts and leaves unsubmitted drafts off the board" do
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    bob = create_user(name: "Bob")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    alice_participation = retro.participations.create!(user: alice)
    bob_participation = retro.participations.create!(user: bob)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    alice_participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Published from Alice")
    alice_participation.update!(submitted_at: Time.current)
    bob_participation.feedback_drafts.create!(retrospective: retro, category: :improve, body: "Bob private draft")

    described_class.new(retro).call

    retro.reload
    expect(retro).to be_discussing
    expect(retro.feedback_items.pluck(:body)).to contain_exactly("Published from Alice")
    expect(retro.feedback_items.pluck(:body)).not_to include("Bob private draft")
    expect(retro.feedback_items.map(&:reveal_position)).to eq([1])
  end

  it "is a no-op when reveal has already completed" do
    facilitator = create_user(name: "Facilitator")
    alice = create_user(name: "Alice")
    team = create_team_with_roles(facilitator: facilitator, members: [alice])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator)
    participation = retro.participations.create!(user: alice)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "The pipeline was stable")
    participation.update!(submitted_at: Time.current)

    described_class.new(retro).call
    expect { described_class.new(retro.reload).call }.not_to raise_error

    retro.reload
    expect(retro).to be_discussing
    expect(retro.feedback_items.pluck(:body)).to contain_exactly("The pipeline was stable")
    expect(retro.feedback_items.pluck(:reveal_position)).to eq([1])
  end
end
