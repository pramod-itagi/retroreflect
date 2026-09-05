require "rails_helper"

RSpec.describe "Concurrent last-facilitator protection", type: :model do
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

  def two_facilitators
    alice = create_user(name: "Alice Fac")
    bob = create_user(name: "Bob Fac")
    team = Team.create!(name: "Race Team", created_by: alice)
    alice_membership = team.memberships.create!(user: alice, role: :facilitator)
    bob_membership = team.memberships.create!(user: bob, role: :facilitator)
    { team: team, alice: alice_membership, bob: bob_membership }
  end

  def run_concurrently(left, right)
    results = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = left.call
          mutex.synchronize { results << result }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = right.call
          mutex.synchronize { results << result }
        end
      end
    ]

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }
    results
  end

  it "does not let concurrent self-demotions leave a team with zero facilitators" do
    data = two_facilitators

    results = run_concurrently(
      -> { data[:alice].update(role: "member") },
      -> { data[:bob].update(role: "member") }
    )

    expect(results).to contain_exactly(true, false)
    expect(data[:team].current_memberships.facilitator.count).to eq(1)
    expect([data[:alice].reload.facilitator?, data[:bob].reload.facilitator?]).to contain_exactly(true, false)
  end

  it "does not let concurrent facilitator removals leave a team with zero facilitators" do
    data = two_facilitators

    results = run_concurrently(
      -> { data[:alice].destroy },
      -> { data[:bob].destroy }
    )

    expect(results.map(&:present?)).to contain_exactly(true, false)
    expect(data[:team].current_memberships.facilitator.count).to eq(1)
    expect(Membership.current.facilitator.where(team: data[:team]).count).to eq(1)
  end
end
