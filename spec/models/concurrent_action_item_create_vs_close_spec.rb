require "rails_helper"

RSpec.describe "Concurrent action item create vs close", type: :model do
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

  def discussing_setup
    facilitator = create_user(name: "Jordan Close")
    owner = create_user(name: "Alice Owner")
    team = create_team_with_roles(facilitator: facilitator, members: [owner], name: "Close Race")
    retro = team.retrospectives.create!(
      title: "Sprint 1 Retrospective - 2026",
      created_by: facilitator,
      status: :discussing,
      revealed_at: Time.current
    )
    { facilitator: facilitator, owner: owner, team: team, retro: retro }
  end

  def build_item(data, title:)
    data[:team].action_items.new(
      title: title,
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Date.current + 1,
      status: :open
    )
  end

  it "rejects create after close has committed" do
    data = discussing_setup
    Retrospectives::Close.new(data[:retro]).call

    item = build_item(data, title: "After close")
    expect(item.persist_for_current_retrospective).to be false
    expect(item.errors.full_messages).to include("This retrospective is no longer accepting action items.")
    expect(data[:team].action_items.find_by(title: "After close")).to be_nil
    expect(data[:retro].reload).to be_closed
  end

  it "never creates an action item after the retrospective is closed" do
    data = discussing_setup
    item = build_item(data, title: "Race item")
    created = nil
    close_error = nil
    mutex = Mutex.new
    barrier = Queue.new

    create_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        result = item.persist_for_current_retrospective
        mutex.synchronize { created = result }
      end
    end

    close_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Retrospectives::Close.new(data[:retro]).call
        rescue Retrospectives::Close::Error => e
          mutex.synchronize { close_error = e }
        end
      end
    end

    2.times { barrier << true }
    [create_thread, close_thread].each { |thread| expect(thread.join(8)).to be_truthy }

    data[:retro].reload
    raced = data[:team].action_items.where(title: "Race item")

    expect(close_error).to be_nil
    expect(data[:retro]).to be_closed
    expect(raced.count).to eq(created ? 1 : 0)
    expect(created).to eq(raced.exists?)
  end
end
