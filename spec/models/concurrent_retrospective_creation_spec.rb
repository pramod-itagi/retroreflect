require "rails_helper"

RSpec.describe "Concurrent retrospective creation", type: :model do
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

  it "does not create duplicate sprint numbers or running retrospectives" do
    facilitator = create_user(name: "Jordan Race")
    team = create_team_with_roles(facilitator: facilitator, name: "Race Team")
    saved = []
    errors = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          retro = Retrospective.new(team: team, created_by: facilitator)
          barrier.pop
          begin
            Team.transaction do
              locked_team = Team.lock.find(team.id)
              retro.assign_attributes(Retrospective.generated_identity_for(locked_team))
              retro.save!
            end
            mutex.synchronize { saved << retro }
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
            mutex.synchronize { errors << e }
          end
        end
      end
    end

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }

    created = Retrospective.where(team_id: team.id)
    expect(created.count).to eq(1)
    expect(created.running.count).to eq(1)
    expect(created.pluck(:sprint_number)).to eq([1])
    expect(errors.size).to eq(1)
  end

  it "does not reuse a sprint number when create races with cancellation" do
    facilitator = create_user(name: "Jordan Cancel Race")
    team = create_team_with_roles(facilitator: facilitator, name: "Cancel Race Team")
    first = nil
    Team.transaction do
      locked_team = Team.lock.find(team.id)
      first = locked_team.retrospectives.new(created_by: facilitator)
      first.assign_attributes(Retrospective.generated_identity_for(locked_team))
      first.save!
    end

    errors = []
    created_ids = []
    mutex = Mutex.new
    barrier = Queue.new

    cancel_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::Cancel.new(Retrospective.find(first.id)).call(cancellation_reason: "race")
        rescue Retrospectives::Cancel::Error => e
          mutex.synchronize { errors << e }
        end
      end
    end

    create_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        retro = Retrospective.new(team: team, created_by: facilitator)
        barrier.pop
        begin
          Team.transaction do
            locked_team = Team.lock.find(team.id)
            retro.assign_attributes(Retrospective.generated_identity_for(locked_team))
            retro.save!
          end
          mutex.synchronize { created_ids << retro.id }
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          mutex.synchronize { errors << e }
        end
      end
    end

    2.times { barrier << true }
    [cancel_thread, create_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    numbers = Retrospective.where(team_id: team.id).where.not(sprint_number: nil).pluck(:sprint_number)
    expect(numbers.uniq).to eq(numbers)
    expect(Retrospective.where(team_id: team.id).running.count).to be <= 1
    expect(first.reload.sprint_number).to eq(1)
  end
end
