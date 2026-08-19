require "rails_helper"

RSpec.describe "Action items", type: :request do
  def setup_item
    facilitator = create_user(name: "Facilitator")
    owner = create_user(name: "Owner")
    other = create_user(name: "Other")
    team = create_team_with_roles(facilitator: facilitator, members: [owner, other])
    retro = team.retrospectives.create!(title: "Sprint 12", created_by: facilitator, status: :discussing)
    item = team.action_items.create!(
      title: "Fix flaky test",
      description: "Stabilize the login spec",
      owner: owner,
      created_by: facilitator,
      retrospective: retro,
      due_on: Date.current + 7,
      status: :open
    )
    { facilitator: facilitator, owner: owner, other: other, team: team, retro: retro, item: item }
  end

  it "lets a facilitator create an item with title, description, owner, due date, and status" do
    context = setup_item
    sign_in(context[:facilitator])

    post facilitator_retrospective_action_items_path(context[:retro]), params: {
      action_item: {
        title: "Document the deploy",
        description: "Add a runbook",
        owner_id: context[:owner].id,
        due_on: Date.current + 3,
        status: "open"
      }
    }

    item = context[:team].action_items.find_by!(title: "Document the deploy")
    expect(item.description).to eq("Add a runbook")
    expect(item.owner).to eq(context[:owner])
    expect(item.due_on).to eq(Date.current + 3)
    expect(item).to be_open
    expect(item.created_by).to eq(context[:facilitator])
    expect(item.retrospective).to eq(context[:retro])
  end

  it "rejects an item whose owner is not on the team" do
    context = setup_item
    outsider = create_user(name: "Outsider")
    sign_in(context[:facilitator])

    expect do
      post facilitator_team_action_items_path(context[:team]), params: {
        action_item: {
          title: "Should fail",
          owner_id: outsider.id,
          due_on: Date.current + 1
        }
      }
    end.not_to(change { context[:team].action_items.count })
  end

  it "lets a facilitator complete or cancel an item and stamps timestamps" do
    context = setup_item
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "completed" } }
    expect(context[:item].reload).to be_completed
    expect(context[:item].completed_at).to be_present
    expect(context[:item].completed_by).to eq(context[:facilitator])

    other_item = context[:team].action_items.create!(
      title: "Drop unused gem",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 2
    )
    patch facilitator_action_item_path(other_item), params: { action_item: { status: "cancelled" } }
    expect(other_item.reload).to be_cancelled
    expect(other_item.cancelled_at).to be_present
    expect(other_item.cancelled_by).to eq(context[:facilitator])
  end

  it "does not let an owner complete an item through the facilitator route" do
    context = setup_item
    sign_in(context[:owner])

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "completed" } }
    expect(response).to redirect_to(root_path)
    expect(context[:item].reload).to be_open
  end

  it "lets an owner see assigned items and update status, but not cancel" do
    context = setup_item
    sign_in(context[:owner])

    get participant_action_items_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fix flaky test")
    expect(response.body).to include("Stabilize the login spec")

    patch participant_action_item_path(context[:item]), params: { action_item: { status: "in_progress" } }
    expect(context[:item].reload).to be_in_progress

    patch participant_action_item_path(context[:item]), params: { action_item: { status: "completed" } }
    expect(context[:item].reload).to be_completed
    expect(context[:item].completed_by).to eq(context[:owner])
    expect(context[:item].completed_at).to be_present

    open_item = context[:team].action_items.create!(
      title: "Write changelog",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 4
    )
    patch participant_action_item_path(open_item), params: { action_item: { status: "cancelled" } }
    expect(response).to redirect_to(root_path)
    expect(open_item.reload).to be_open
  end

  it "does not let a teammate update someone else's action item" do
    context = setup_item
    sign_in(context[:other])

    get participant_action_items_path
    expect(response.body).not_to include("Fix flaky test")

    patch participant_action_item_path(context[:item]), params: { action_item: { status: "in_progress" } }
    expect(response).to redirect_to(root_path)
    expect(context[:item].reload).to be_open
  end

  it "does not let a non-facilitator create an action item" do
    context = setup_item
    sign_in(context[:owner])

    post facilitator_retrospective_action_items_path(context[:retro]), params: {
      action_item: {
        title: "Unauthorized",
        owner_id: context[:owner].id,
        due_on: Date.current + 1
      }
    }

    expect(response).to redirect_to(root_path)
    expect(context[:team].action_items.find_by(title: "Unauthorized")).to be_nil
  end

  it "does not allow status changes after an item is completed" do
    context = setup_item
    context[:item].update!(status: "completed")
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "open" } }
    expect(context[:item].reload).to be_completed
  end
end
