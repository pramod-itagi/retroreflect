require "rails_helper"

RSpec.describe "Concurrent start collecting", type: :model do
  include ActiveJob::TestHelper
  self.use_transactional_tests = false

  def cleanup!
    ActionItem.delete_all
    ActionItemStatusEvent.delete_all
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

  it "starts collecting once and does not duplicate invitations" do
    facilitator = create_user(name: "Jordan Invite")
    alice = create_user(name: "Alice Invite")
    bob = create_user(name: "Bob Invite")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob], name: "Invite Race")
    retro = team.retrospectives.create!(title: "Sprint 1 Retrospective - 2026", created_by: facilitator)
    alice_participation = retro.participations.create!(user: alice)
    bob_participation = retro.participations.create!(user: bob)

    clear_enqueued_jobs
    errors = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          begin
            Retrospectives::StartCollecting.new(retro).call
          rescue Retrospectives::StartCollecting::Error => e
            mutex.synchronize { errors << e }
          end
        end
      end
    end

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }

    retro.reload
    alice_participation.reload
    bob_participation.reload
    first_tokens = [alice_participation.invitation_token_digest, bob_participation.invitation_token_digest]

    expect(errors.size).to eq(1)
    expect(errors.first.message).to include("draft").or include("already invited")
    expect(retro).to be_collecting
    expect(alice_participation.invited_at).to be_present
    expect(bob_participation.invited_at).to be_present
    expect(first_tokens).to all(be_present)
    expect(first_tokens.uniq.size).to eq(2)
    expect(SendRetroInvitationJob).to have_been_enqueued.exactly(2).times

    expect do
      Retrospectives::StartCollecting.new(retro).call
    end.to raise_error(Retrospectives::StartCollecting::Error)
    expect(SendRetroInvitationJob).to have_been_enqueued.exactly(2).times

    alice_participation.reload
    bob_participation.reload
    expect([alice_participation.invitation_token_digest, bob_participation.invitation_token_digest]).to eq(first_tokens)
  end
end
