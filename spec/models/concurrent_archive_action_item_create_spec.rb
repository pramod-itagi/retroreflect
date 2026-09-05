require "rails_helper"

RSpec.describe "Concurrent archive and action item create", type: :model do
  self.use_transactional_tests = false

  def cleanup!
    ActionItemStatusEvent.delete_all
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

  it "never leaves an archived team with a newly created unresolved action item" do
    facilitator = create_user(name: "Jordan Archive")
    owner = create_user(name: "Alice Owner")
    team = create_team_with_roles(facilitator: facilitator, members: [owner], name: "Archive Create Race")
    retro = team.retrospectives.create!(
      title: "Sprint 1 Retrospective - 2026",
      created_by: facilitator,
      status: :discussing,
      revealed_at: Time.current
    )
    item = team.action_items.new(
      title: "Race create",
      owner: owner,
      created_by: facilitator,
      retrospective: retro,
      due_on: Date.current + 1
    )

    created = nil
    archive_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    create_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        result = item.persist_for_current_retrospective(authorized_by: facilitator)
        mutex.synchronize { created = result }
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
    [create_thread, archive_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    team.reload
    raced = team.action_items.where(title: "Race create")

    expect(team.archived? && raced.unresolved.exists?).to be(false)
    expect(created).to eq(raced.exists?)
    if team.archived?
      expect(raced).to be_empty
      expect(archive_error).to be_nil
    else
      expect(archive_error).to be_present
      expect(retro.reload).to be_discussing
    end
  end

  it "rejects create once archive has committed on a closed retrospective" do
    facilitator = create_user(name: "Jordan Closed")
    owner = create_user(name: "Alice Closed")
    team = create_team_with_roles(facilitator: facilitator, members: [owner], name: "Closed Archive Race")
    retro = team.retrospectives.create!(
      title: "Sprint 1 Retrospective - 2026",
      created_by: facilitator,
      status: :closed,
      closed_at: Time.current
    )
    item = team.action_items.new(
      title: "After closed archive",
      owner: owner,
      created_by: facilitator,
      retrospective: retro,
      due_on: Date.current + 1
    )

    created = nil
    archive_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    create_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        result = item.persist_for_current_retrospective(authorized_by: facilitator)
        mutex.synchronize { created = result }
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
    [create_thread, archive_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    team.reload
    expect(created).to be(false)
    expect(archive_error).to be_nil
    expect(team).to be_archived
    expect(team.action_items.where(title: "After closed archive")).to be_empty
  end
end
