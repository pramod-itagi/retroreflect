require "rails_helper"

RSpec.describe ActionItem, type: :model do
  def setup
    facilitator = create_user(name: "Facilitator")
    owner = create_user(name: "Owner")
    team = create_team_with_roles(facilitator: facilitator, members: [owner])
    { facilitator: facilitator, owner: owner, team: team }
  end

  it "rejects a past due date on create but allows updating an overdue item" do
    data = setup
    past = Time.zone.yesterday

    item = data[:team].action_items.build(
      title: "Past due",
      owner: data[:owner],
      created_by: data[:facilitator],
      due_on: past
    )
    expect(item).not_to be_valid
    expect(item.errors[:due_on]).to include("must be today or a future date")

    created = data[:team].action_items.create!(
      title: "Becomes overdue",
      owner: data[:owner],
      created_by: data[:facilitator],
      due_on: Time.zone.today
    )
    created.update!(due_on: past)
    expect(created.reload.due_on).to eq(past)
    expect(created).to be_valid
  end

  it "does not create a status event when status does not change" do
    data = setup
    item = data[:team].action_items.create!(
      title: "Stay open",
      owner: data[:owner],
      created_by: data[:facilitator],
      due_on: Time.zone.today
    )

    expect(item.apply_status_change("open", comment: "ignored", actor: data[:facilitator])).to be(true)
    expect(item.status_events).to be_empty
  end
end
