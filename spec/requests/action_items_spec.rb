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

  it "shows unresolved team action items on the team page without a create form" do
    context = setup_item
    due = Date.new(2026, 8, 25)
    context[:item].update!(due_on: due, title: "Improve CI pipeline")
    context[:team].action_items.create!(
      title: "Improve deployment",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.new(2026, 8, 28),
      status: :in_progress
    )
    context[:team].action_items.create!(
      title: "Ready for review item",
      owner: context[:other],
      created_by: context[:facilitator],
      due_on: Date.new(2026, 8, 30),
      status: :ready_for_review
    )
    context[:team].action_items.create!(
      title: "Update documentation",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: due,
      status: :completed,
      completed_at: Time.current,
      completed_by: context[:owner]
    )
    context[:team].action_items.create!(
      title: "Cancelled extra work",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: due,
      status: :cancelled,
      cancelled_at: Time.current,
      cancelled_by: context[:facilitator]
    )
    create_user(name: "Available Person")

    sign_in(context[:facilitator])
    get facilitator_team_path(context[:team])

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Current Action Items")
    expect(response.body).to include("Improve CI pipeline")
    expect(response.body).to include("Improve deployment")
    expect(response.body).to include("Ready for review item")
    expect(response.body).to include("Owner ·")
    expect(response.body).to include("In progress")
    expect(response.body).to include("Ready for review")
    expect(response.body).to include("Due Aug 25")
    expect(response.body).not_to include("Update documentation")
    expect(response.body).not_to include("Cancelled extra work")
    expect(response.body).not_to include("Add action item")
    expect(response.body).not_to include(facilitator_team_action_items_path(context[:team]))
    expect(response.body).to include("View all action items")
    expect(response.body).to include(participant_action_items_path)
    expect(response.body).to include("Current retrospective")
    expect(response.body).to include("View retrospective history")
    expect(response.body).to include("Select a confirmed user")
    expect(response.body).to include("pr-10")
    expect(response.body).to include("Archive Team")
    expect(response.body).to include("Archiving removes all current members from this team and prevents new retrospectives.")
    expect(response.body).not_to include("Archive team")

    get facilitator_retrospective_meeting_path(context[:retro])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Add action item")
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
    expect(response.body).to include("Update")

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

  it "marks overdue owned items and shows an empty state when none are assigned" do
    context = setup_item
    context[:item].update!(due_on: Date.current - 1)

    sign_in(context[:owner])
    get participant_action_items_path
    expect(response.body).to include("Overdue")
    expect(response.body).to include("Your action items")

    sign_in(context[:other])
    get participant_action_items_path
    expect(response.body).to include("No action items")
    expect(response.body).not_to include("Fix flaky test")
  end

  it "hides the team View all link when there are no current action items" do
    facilitator = create_user(name: "Facilitator")
    team = create_team_with_roles(facilitator: facilitator)

    sign_in(facilitator)
    get facilitator_team_path(team)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No current action items.")
    expect(response.body).not_to include("View all action items")
  end
end
