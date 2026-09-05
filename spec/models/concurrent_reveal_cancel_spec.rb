require "rails_helper"

RSpec.describe "Concurrent reveal and cancel", type: :model do
  self.use_transactional_tests = false

  def cleanup!
    ActionItem.delete_all
    FeedbackItem.delete_all
    FeedbackDraft.delete_all
    Participation.delete_all
    Retrospective.delete_all
    Membership.delete_all
    Team.delete_all
    User.delete_all
  end

  before { cleanup! }
  after { cleanup! }

  it "does not interleave reveal and cancel into an impossible state" do
    facilitator = create_user(name: "Jordan Reveal")
    member = create_user(name: "Alice Reveal")
    team = create_team_with_roles(facilitator: facilitator, members: [member], name: "Reveal Cancel Race")
    retro = team.retrospectives.create!(title: "Sprint 1 Retrospective - 2026", created_by: facilitator)
    participation = retro.participations.create!(user: member)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    participation.feedback_drafts.create!(retrospective: retro, category: :went_well, body: "Published note")
    participation.update!(submitted_at: Time.current)

    reveal_error = nil
    cancel_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    reveal_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::Reveal.new(retro).call
        rescue Retrospectives::Reveal::Error => e
          mutex.synchronize { reveal_error = e }
        end
      end
    end

    cancel_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::Cancel.new(retro).call
        rescue Retrospectives::Cancel::Error => e
          mutex.synchronize { cancel_error = e }
        end
      end
    end

    2.times { barrier << true }
    [reveal_thread, cancel_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    retro.reload
    expect(retro.discussing? && retro.cancelled?).to be(false)
    expect(retro.discussing? ^ retro.cancelled?).to be(true)
    expect([reveal_error, cancel_error].compact.size).to eq(1)

    if retro.discussing?
      expect(FeedbackItem.where(retrospective: retro).pluck(:body)).to include("Published note")
      expect(retro.feedback_drafts).to be_empty
    else
      expect(FeedbackItem.where(retrospective: retro)).to be_empty
    end
  end
end
