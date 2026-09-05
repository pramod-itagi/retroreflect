require "rails_helper"

RSpec.describe "Concurrent system admin revocation", type: :model do
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

  it "does not leave the system with zero system admins" do
    alice = create_user(name: "Alice Race", system_admin: true)
    bob = create_user(name: "Bob Race", system_admin: true)
    results = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = alice.revoke_system_admin
          mutex.synchronize { results << result }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = bob.revoke_system_admin
          mutex.synchronize { results << result }
        end
      end
    ]

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }

    expect(results).to contain_exactly(true, false)
    expect(User.system_admins.count).to eq(1)
    expect([alice.reload.system_admin?, bob.reload.system_admin?]).to contain_exactly(true, false)
  end

  it "does not let concurrent self-leaves remove the last system admin" do
    alice = create_user(name: "Alice Leave", system_admin: true)
    bob = create_user(name: "Bob Leave", system_admin: true)
    results = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = alice.revoke_system_admin(as_self: true)
          mutex.synchronize { results << result }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          result = bob.revoke_system_admin(as_self: true)
          mutex.synchronize { results << result }
        end
      end
    ]

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }

    expect(results).to contain_exactly(true, false)
    expect(User.system_admins.count).to eq(1)
  end
end
