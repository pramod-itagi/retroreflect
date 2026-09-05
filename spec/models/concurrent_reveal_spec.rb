require "rails_helper"

RSpec.describe "Concurrent retrospective reveal", type: :model do
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

  def collecting_setup
    facilitator = create_user(name: "Jordan Reveal")
    alice = create_user(name: "Alice Reveal")
    bob = create_user(name: "Bob Reveal")
    team = create_team_with_roles(facilitator: facilitator, members: [alice, bob], name: "Reveal Race")
    retro = team.retrospectives.create!(title: "Sprint 1 Retrospective - 2026", created_by: facilitator)
    alice_participation = retro.participations.create!(user: alice)
    bob_participation = retro.participations.create!(user: bob)
    retro.update!(status: :collecting, collecting_started_at: Time.current)
    {
      facilitator: facilitator,
      alice: alice,
      bob: bob,
      team: team,
      retro: retro,
      alice_participation: alice_participation,
      bob_participation: bob_participation
    }
  end

  def add_draft(participation, body:, category: :went_well)
    participation.feedback_drafts.create!(
      retrospective: participation.retrospective,
      category: category,
      body: body
    )
  end

  it "does not create duplicate feedback items or reveal positions" do
    data = collecting_setup
    add_draft(data[:alice_participation], body: "Standups were focused")
    add_draft(data[:alice_participation], body: "Handoffs still take too long", category: :improve)
    data[:alice_participation].update!(submitted_at: Time.current)
    add_draft(data[:bob_participation], body: "Bob private draft")

    errors = []
    mutex = Mutex.new
    barrier = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          begin
            Retrospectives::Reveal.new(data[:retro]).call
          rescue StandardError => e
            mutex.synchronize { errors << e }
          end
        end
      end
    end

    2.times { barrier << true }
    threads.each { |thread| expect(thread.join(8)).to be_truthy }

    data[:retro].reload
    items = data[:retro].feedback_items.order(:reveal_position)
    expect(errors).to be_empty
    expect(data[:retro]).to be_discussing
    expect(items.pluck(:body)).to contain_exactly("Standups were focused", "Handoffs still take too long")
    expect(items.pluck(:body)).not_to include("Bob private draft")
    expect(items.pluck(:reveal_position)).to eq([1, 2])
    expect(FeedbackItem.where(retrospective: data[:retro]).count).to eq(2)
  end

  it "does not silently lose eligible submitted feedback when submit races reveal" do
    data = collecting_setup
    add_draft(data[:alice_participation], body: "Alice submitted note")
    data[:alice_participation].update!(submitted_at: Time.current)
    add_draft(data[:bob_participation], body: "Bob last-second note")

    submitted = nil
    reveal_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    submit_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        result = data[:bob_participation].submit_responses
        mutex.synchronize { submitted = result }
      end
    end

    reveal_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::Reveal.new(data[:retro]).call
        rescue Retrospectives::Reveal::Error => e
          mutex.synchronize { reveal_error = e }
        end
      end
    end

    2.times { barrier << true }
    [submit_thread, reveal_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    data[:retro].reload
    data[:bob_participation].reload
    bodies = data[:retro].feedback_items.pluck(:body)

    expect(reveal_error).to be_nil
    expect(data[:retro]).to be_discussing
    expect(bodies).to include("Alice submitted note")
    if data[:bob_participation].submitted?
      expect(submitted).to be(true)
      expect(bodies).to include("Bob last-second note")
    else
      expect(bodies).not_to include("Bob last-second note")
    end
  end

  it "does not publish an unsubmitted save that races reveal" do
    data = collecting_setup
    add_draft(data[:alice_participation], body: "Alice submitted note")
    data[:alice_participation].update!(submitted_at: Time.current)
    bob_draft = add_draft(data[:bob_participation], body: "Bob first draft")

    save_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    save_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          FeedbackDrafts::SaveBatch.new(
            participation: data[:bob_participation],
            retrospective: data[:retro],
            drafts: { bob_draft.id.to_s => { body: "Bob edited during reveal" } },
            new_drafts: { improve: ["Bob extra during reveal"] }
          ).call
        rescue StandardError => e
          mutex.synchronize { save_error = e }
        end
      end
    end

    reveal_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        Retrospectives::Reveal.new(data[:retro]).call
      end
    end

    2.times { barrier << true }
    [save_thread, reveal_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    data[:retro].reload
    bodies = data[:retro].feedback_items.pluck(:body)

    expect(data[:retro]).to be_discussing
    expect(bodies).to contain_exactly("Alice submitted note")
    expect(bodies).not_to include("Bob first draft", "Bob edited during reveal", "Bob extra during reveal")
    expect(save_error).to satisfy { |error| error.nil? || error.is_a?(ActiveRecord::RecordInvalid) }
  end
end
