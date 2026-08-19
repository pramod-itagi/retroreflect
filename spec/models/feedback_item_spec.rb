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

    described_class.new(retro).call

    retro.reload
    expect(retro).to be_discussing
    expect(FeedbackDraft.where(retrospective: retro)).to be_empty
    item = FeedbackItem.find_by!(retrospective: retro)
    expect(item.body).to eq("The pipeline was stable")
    expect(item.reveal_position).to eq(1)
    expect(item.attributes.keys).not_to include("user_id", "participation_id")
  end
end
