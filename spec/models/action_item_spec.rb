require "rails_helper"

RSpec.describe ActionItem, type: :model do
  def setup
    facilitator = create_user(name: "Facilitator")
    owner = create_user(name: "Owner")
    team = create_team_with_roles(facilitator: facilitator, members: [owner])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator, status: :discussing)
    { facilitator: facilitator, owner: owner, team: team, retro: retro }
  end

  it "rejects a past due date on create but allows updating an overdue item" do
    data = setup
    past = Time.zone.yesterday

    item = data[:team].action_items.build(
      title: "Past due",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: past
    )
    expect(item).not_to be_valid
    expect(item.errors[:due_on]).to include("must be today or a future date")

    created = data[:team].action_items.create!(
      title: "Becomes overdue",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today
    )
    created.update!(due_on: past)
    expect(created.reload.due_on).to eq(past)
    expect(created).to be_valid
  end

  it "creates every new action item as Open and ignores another requested status" do
    data = setup
    item = data[:team].action_items.create!(
      title: "Should stay open",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today,
      status: :completed
    )

    expect(item).to be_open
    expect(item.completed_at).to be_nil
    expect(item.status_events).to be_empty
  end

  it "does not create a status event when status does not change" do
    data = setup
    item = data[:team].action_items.create!(
      title: "Stay open",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today
    )

    expect(item.apply_status_change("open", comment: "ignored", actor: data[:facilitator])).to be(true)
    expect(item.status_events).to be_empty
  end

  it "requires a retrospective on create and rejects team-only persistence" do
    data = setup
    item = data[:team].action_items.new(
      title: "No retro",
      owner: data[:owner],
      created_by: data[:facilitator],
      due_on: Time.zone.today
    )

    expect(item).not_to be_valid
    expect(item.errors[:retrospective]).to be_present
    expect(item.persist_for_current_retrospective(authorized_by: data[:facilitator])).to be(false)
    expect(item.errors[:retrospective]).to be_present
    expect(data[:team].action_items.find_by(title: "No retro")).to be_nil
  end

  it "rejects persistence after the retrospective is cancelled or the team is archived" do
    data = setup
    data[:retro].update!(status: :cancelled, cancelled_at: Time.current)
    cancelled_item = data[:team].action_items.new(
      title: "After cancel",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today
    )
    expect(cancelled_item.persist_for_current_retrospective(authorized_by: data[:facilitator])).to be(false)
    expect(data[:team].action_items.find_by(title: "After cancel")).to be_nil

    data[:retro].update!(status: :discussing, cancelled_at: nil)
    Team.transaction do
      data[:team].lock!
      now = Time.current
      data[:team].memberships.current.update_all(deactivated_at: now)
      data[:team].update!(archived_at: now)
    end
    archived_item = data[:team].action_items.new(
      title: "After archive",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today
    )
    expect(archived_item.persist_for_current_retrospective(authorized_by: data[:facilitator])).to be(false)
    expect(data[:team].action_items.find_by(title: "After archive")).to be_nil
  end

  it "still allows updates to an existing item that has no retrospective" do
    data = setup
    item = data[:team].action_items.create!(
      title: "Legacy item",
      owner: data[:owner],
      created_by: data[:facilitator],
      retrospective: data[:retro],
      due_on: Time.zone.today
    )
    item.update_column(:retrospective_id, nil)

    expect(item.reload.update(due_on: Time.zone.today + 1)).to be(true)
    expect(item.apply_status_change("in_progress", comment: "Started the leftover work.", actor: data[:facilitator])).to be(true)
    expect(item.reload).to be_in_progress
  end
end
