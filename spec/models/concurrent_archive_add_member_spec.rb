require "rails_helper"

RSpec.describe "Concurrent archive and add member", type: :model do
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

  it "never leaves a current membership on an archived team" do
    facilitator = create_user(name: "Jordan Archive")
    extra = create_user(name: "Morgan Extra")
    team = create_team_with_roles(facilitator: facilitator, name: "Archive Member Race")

    created = nil
    archive_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    add_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        membership = Team.find(team.id).memberships.new(user: User.find(extra.id), role: :member)
        result = membership.save
        mutex.synchronize { created = result }
      end
    end

    archive_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Teams::Archive.new(Team.find(team.id)).call
        rescue Teams::Archive::Error => e
          mutex.synchronize { archive_error = e }
        end
      end
    end

    2.times { barrier << true }
    [add_thread, archive_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    team.reload
    extra_membership = team.memberships.find_by(user: extra)

    expect(team).to be_archived
    expect(archive_error).to be_nil
    expect(extra_membership&.current?).to be_falsey
    expect(team.current_memberships.where(user: extra)).to be_empty
    if extra_membership
      expect(extra_membership).not_to be_current
      expect(created).to be(true)
    else
      expect(created).to be(false)
    end
  end
end
