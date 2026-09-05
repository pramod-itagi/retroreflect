require "rails_helper"

RSpec.describe "Concurrent archive and start collecting", type: :model do
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

  it "never leaves an archived team with a collecting retrospective" do
    facilitator = create_user(name: "Jordan Archive")
    member = create_user(name: "Alice Archive")
    team = create_team_with_roles(facilitator: facilitator, members: [member], name: "Archive Race")
    retro = team.retrospectives.create!(title: "Sprint 1 Retrospective - 2026", created_by: facilitator)
    retro.participations.create!(user: member)

    start_error = nil
    archive_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    start_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::StartCollecting.new(retro).call
        rescue Retrospectives::StartCollecting::Error => e
          mutex.synchronize { start_error = e }
        end
      end
    end

    archive_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Teams::Archive.new(team).call
        rescue Teams::Archive::Error => e
          mutex.synchronize { archive_error = e }
        end
      end
    end

    2.times { barrier << true }
    [start_thread, archive_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    team.reload
    retro.reload

    expect(team.archived? && retro.collecting?).to be(false)
    expect(
      (team.archived? && retro.cancelled?) || (team.active? && retro.collecting?)
    ).to be(true)

    if team.archived?
      expect(start_error).to be_present
      expect(retro).to be_cancelled
    else
      expect(archive_error).to be_present
      expect(retro).to be_collecting
      expect(archive_error.message).to include("active retrospective")
    end
  end
end
