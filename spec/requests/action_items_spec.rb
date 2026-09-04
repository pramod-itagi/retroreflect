require "rails_helper"

RSpec.describe "Action items", type: :request do
  include ActiveSupport::Testing::TimeHelpers
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

  def status_change_params(status, comment: "Updated the work.")
    { action_item: { status: status, status_comment: comment } }
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

  it "presents the action item creation form with the expected fields and defaults" do
    context = setup_item
    sign_in(context[:facilitator])
    get facilitator_retrospective_meeting_path(context[:retro])

    form = response.parsed_body.at_css("form.action-item-create")
    expect(form).to be_present
    expect(form["class"]).to include("home-card")
    expect(form.at_css("input[name='action_item[title]']")["placeholder"]).to eq("e.g. Improve deployment process")
    expect(form.at_css("select[name='action_item[owner_id]']")["class"]).to include("workspace-field")
    expect(form.css("svg.action-item-field-icon").size).to eq(2)
    expect(form.at_css(".action-item-status-dot")).to be_present
    expect(form.at_css(".action-item-date-display")).to be_present
    due_on = form.at_css("input[name='action_item[due_on]']")
    expect(due_on["class"]).to include("action-item-date-native")
    expect(due_on["min"]).to eq(Time.zone.today.iso8601)
    status = form.at_css("select[name='action_item[status]']")
    expect(status["class"]).to include("workspace-field")
    expect(status.at("option[selected]")["value"]).to eq("open")
    expect(form.at_css("textarea[name='action_item[description]']")["placeholder"]).to include("optional")
    expect(form.at_css("[type='submit']")["value"]).to eq("Add action item")
  end

  def status_select_on_meeting(item)
    response.parsed_body.css("form[action='#{facilitator_action_item_path(item)}'] select[name='action_item[status]']").first
  end

  it "keeps Open selected and unchanged when Update is clicked without changing status" do
    context = setup_item
    sign_in(context[:facilitator])

    get facilitator_retrospective_meeting_path(context[:retro])
    select = status_select_on_meeting(context[:item])
    expect(select.css("option").map { |option| option["value"] }).to eq(
      %w[open in_progress ready_for_review completed cancelled]
    )
    expect(select.at("option[selected]")["value"]).to eq("open")
    expect(select.text).to include("In progress")

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "open" } }
    expect(context[:item].reload).to be_open
  end

  it "gives each action item status select a unique accessible name" do
    context = setup_item
    other = context[:team].action_items.create!(
      title: "Keep this open",
      owner: context[:owner],
      created_by: context[:facilitator],
      retrospective: context[:retro],
      due_on: Date.current + 2,
      status: :open
    )
    sign_in(context[:facilitator])
    get facilitator_retrospective_meeting_path(context[:retro])

    first = status_select_on_meeting(context[:item])
    second = status_select_on_meeting(other)
    expect(first["id"]).to eq("action_item_#{context[:item].id}_status")
    expect(second["id"]).to eq("action_item_#{other.id}_status")
    expect(first["id"]).not_to eq(second["id"])

    first_label = response.parsed_body.at_css("label[for='#{first['id']}']")
    second_label = response.parsed_body.at_css("label[for='#{second['id']}']")
    expect(first_label["class"]).to include("sr-only")
    expect(first_label.text).to eq("Status for #{context[:item].title}")
    expect(second_label.text).to eq("Status for #{other.title}")
  end

  it "lets a facilitator move through the lifecycle without toggling on no-op updates" do
    context = setup_item
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started working on the flaky spec.")
    expect(context[:item].reload).to be_in_progress

    get facilitator_retrospective_meeting_path(context[:retro])
    select = status_select_on_meeting(context[:item])
    expect(select.css("option").map { |option| option["value"] }).to include("in_progress")
    expect(select.at("option[selected]")["value"]).to eq("in_progress")

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "in_progress" } }
    expect(context[:item].reload).to be_in_progress

    patch facilitator_action_item_path(context[:item]), params: status_change_params("ready_for_review", comment: "Implementation is complete. Please review.")
    expect(context[:item].reload).to be_ready_for_review

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "ready_for_review" } }
    expect(context[:item].reload).to be_ready_for_review

    patch facilitator_action_item_path(context[:item]), params: status_change_params("completed", comment: "Reviewed and merged.")
    expect(context[:item].reload).to be_completed
  end

  it "lets a facilitator cancel an open item without changing status when the same status is resubmitted" do
    context = setup_item
    sign_in(context[:facilitator])

    other = context[:team].action_items.create!(
      title: "Keep this open",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 2,
      status: :open
    )
    patch facilitator_action_item_path(other), params: { action_item: { status: "open" } }
    expect(other.reload).to be_open

    patch facilitator_action_item_path(context[:item]), params: status_change_params("cancelled", comment: "The integration is no longer required.")
    expect(context[:item].reload).to be_cancelled
    expect(context[:item].cancelled_at).to be_present
  end

  it "lets an owner keep the current status when Update is submitted without a change" do
    context = setup_item
    sign_in(context[:owner])

    get participant_action_items_path
    select = response.parsed_body.css("form[action='#{participant_action_item_path(context[:item])}'] select[name='action_item[status]']").first
    expect(select.css("option").map { |option| option["value"] }).to include("open", "in_progress")
    expect(select.at("option[selected]")["value"]).to eq("open")
    expect(select.css("option").map { |option| option["value"] }).not_to include("cancelled")

    patch participant_action_item_path(context[:item]), params: { action_item: { status: "open" } }
    expect(context[:item].reload).to be_open

    patch participant_action_item_path(context[:item]), params: status_change_params("in_progress")
    expect(context[:item].reload).to be_in_progress

    patch participant_action_item_path(context[:item]), params: { action_item: { status: "in_progress" } }
    expect(context[:item].reload).to be_in_progress
  end

  it "does not change status when unrelated fields are submitted with the current status" do
    context = setup_item
    sign_in(context[:facilitator])
    original_title = context[:item].title
    original_due_on = context[:item].due_on

    patch facilitator_action_item_path(context[:item]), params: {
      action_item: {
        status: "open",
        title: "Should not replace the title",
        description: "Should not replace the description",
        due_on: Date.current + 30,
        owner_id: context[:other].id
      }
    }

    context[:item].reload
    expect(context[:item]).to be_open
    expect(context[:item].title).to eq(original_title)
    expect(context[:item].due_on).to eq(original_due_on)
    expect(context[:item].owner).to eq(context[:owner])
  end

  it "shows unresolved team action items on the team page without a create form" do
    context = setup_item
    due = Date.new(2026, 8, 25)
    context[:item].update!(due_on: due, title: "Improve CI pipeline")
    context[:team].action_items.create!(
      title: "Improve deployment",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 1,
      status: :in_progress
    ).update!(due_on: Date.new(2026, 8, 28))
    context[:team].action_items.create!(
      title: "Ready for review item",
      owner: context[:other],
      created_by: context[:facilitator],
      due_on: Date.current + 1,
      status: :ready_for_review
    ).update!(due_on: Date.new(2026, 8, 30))
    completed = context[:team].action_items.create!(
      title: "Update documentation",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 1,
      status: :completed,
      completed_at: Time.current,
      completed_by: context[:owner]
    )
    completed.update!(due_on: due)
    cancelled = context[:team].action_items.create!(
      title: "Cancelled extra work",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 1,
      status: :cancelled,
      cancelled_at: Time.current,
      cancelled_by: context[:facilitator]
    )
    cancelled.update!(due_on: due)
    create_user(name: "Available Person")

    sign_in(context[:facilitator])
    get facilitator_team_path(context[:team])

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Current action items")
    expect(response.body).to include("Improve CI pipeline")
    expect(response.body).to include("Improve deployment")
    expect(response.body).to include("Ready for review item")
    current_items = response.parsed_body.css("ul.home-card").find { |list| list.text.include?("Improve CI pipeline") }
    expect(current_items.css("li").size).to eq(3)
    expect(current_items["class"]).to include("divide-y")
    expect(response.body).to include("Owner ·")
    expect(response.body).to include("In progress")
    expect(response.body).to include("Ready for review")
    expect(response.body).to include("Due Aug 25, 2026")
    expect(response.body).not_to include("Update documentation")
    expect(response.body).not_to include("Cancelled extra work")
    expect(response.body).not_to include("Add action item")
    expect(response.body).not_to include(facilitator_team_action_items_path(context[:team]))
    expect(response.body).to include("View all action items")
    expect(response.body).to include(participant_action_items_path)
    expect(response.body).to include("Current retrospective")
    expect(response.body).to include("View retrospective history")
    expect(response.body).to include("Select a confirmed user")
    add_person = response.parsed_body.css(".home-card").find { |card| card.text.include?("Add person") }
    expect(add_person.at_css("select[name='user_id']")["class"]).to include("workspace-field")
    expect(add_person.at_css("select[name='role']")["class"]).to include("workspace-field")
    expect(add_person.at_css("select[name='user_id']")["class"]).not_to include("workspace-filter-field")
    expect(response.body).to include("Archive team")
    expect(response.body).to include("Archiving removes all current members from this team and prevents new retrospectives.")

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

    patch facilitator_action_item_path(context[:item]), params: status_change_params("completed", comment: "Reviewed and merged.")
    expect(context[:item].reload).to be_completed
    expect(context[:item].completed_at).to be_present
    expect(context[:item].completed_by).to eq(context[:facilitator])

    other_item = context[:team].action_items.create!(
      title: "Drop unused gem",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 2
    )
    patch facilitator_action_item_path(other_item), params: status_change_params("cancelled", comment: "The integration is no longer required.")
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
    expect(response.body).to include("Due #{context[:item].due_on.strftime("%b #{context[:item].due_on.day}, %Y")}")
    expect(response.body).to include("Update")

    patch participant_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started implementation.")
    expect(context[:item].reload).to be_in_progress

    patch participant_action_item_path(context[:item]), params: status_change_params("completed", comment: "Reviewed and merged.")
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

  it "hides creation on a closed retrospective, keeps existing items updatable, and rejects create" do
    context = setup_item
    sign_in(context[:facilitator])

    get facilitator_retrospective_path(context[:retro])
    expect(response.body).to include("Add action item")
    expect(response.body).to include("Fix flaky test")

    get facilitator_retrospective_meeting_path(context[:retro])
    expect(response.body).to include("Add action item")
    expect(response.body).to include("Fix flaky test")

    context[:retro].update!(status: :closed, closed_at: Time.current)

    get facilitator_retrospective_path(context[:retro])
    expect(response.body).not_to include("Add action item")
    expect(response.body).not_to include('name="action_item[title]"')
    expect(response.body).to include("Fix flaky test")
    expect(response.body).to include("Update")

    get facilitator_retrospective_meeting_path(context[:retro])
    expect(response.body).not_to include("Add action item")
    expect(response.body).not_to include('name="action_item[title]"')
    expect(response.body).to include("Fix flaky test")
    expect(response.body).to include("Update")

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started after close.")
    expect(context[:item].reload).to be_in_progress

    expect do
      post facilitator_retrospective_action_items_path(context[:retro]), params: {
        action_item: {
          title: "Should not be created",
          owner_id: context[:owner].id,
          due_on: Date.current + 1,
          status: "open"
        }
      }
    end.not_to(change { context[:team].action_items.count })

    expect(response).to redirect_to(root_path)
    expect(context[:team].action_items.find_by(title: "Should not be created")).to be_nil
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

    due_label = "Due #{context[:item].due_on.strftime("%b #{context[:item].due_on.day}, %Y")}"

    sign_in(context[:owner])
    get participant_action_items_path
    expect(response.body).to include("Overdue")
    expect(response.body).to include(due_label)
    expect(response.body).not_to include(context[:item].due_on.iso8601)
    expect(response.body).to include("Your action items")

    sign_in(context[:facilitator])
    get facilitator_team_path(context[:team])
    expect(response.body).to include("Overdue")
    expect(response.body).to include(due_label)
    expect(response.body).not_to include(context[:item].due_on.iso8601)

    get facilitator_retrospective_meeting_path(context[:retro])
    expect(response.body).to include("Overdue")
    expect(response.body).to include(due_label)
    expect(response.body).not_to include(context[:item].due_on.iso8601)

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

  it "rejects a new action item with a past due date and allows today or a future date" do
    context = setup_item
    sign_in(context[:facilitator])

    expect do
      post facilitator_retrospective_action_items_path(context[:retro]), params: {
        action_item: {
          title: "Past due item",
          owner_id: context[:owner].id,
          due_on: Time.zone.yesterday,
          status: "open"
        }
      }
    end.not_to(change { context[:team].action_items.count })
    expect(flash[:alert]).to include("must be today or a future date")

    expect do
      post facilitator_retrospective_action_items_path(context[:retro]), params: {
        action_item: {
          title: "Due today",
          owner_id: context[:owner].id,
          due_on: Time.zone.today,
          status: "open"
        }
      }
    end.to change { context[:team].action_items.count }.by(1)

    expect do
      post facilitator_retrospective_action_items_path(context[:retro]), params: {
        action_item: {
          title: "Due next week",
          owner_id: context[:owner].id,
          due_on: Time.zone.today + 7,
          status: "open"
        }
      }
    end.to change { context[:team].action_items.count }.by(1)
  end

  it "still rejects a blank due date because due dates remain required" do
    context = setup_item
    sign_in(context[:facilitator])

    expect do
      post facilitator_retrospective_action_items_path(context[:retro]), params: {
        action_item: {
          title: "No due date",
          owner_id: context[:owner].id,
          due_on: "",
          status: "open"
        }
      }
    end.not_to(change { context[:team].action_items.count })
  end

  it "lets an existing overdue action item change status" do
    context = setup_item
    context[:item].update!(due_on: Time.zone.yesterday)
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started the overdue work.")

    context[:item].reload
    expect(context[:item]).to be_in_progress
    expect(context[:item].due_on).to eq(Time.zone.yesterday)
    expect(context[:item].status_events.last.comment).to eq("Started the overdue work.")
  end

  it "uses the application timezone when deciding whether a due date is in the past" do
    context = setup_item
    sign_in(context[:facilitator])

    travel_to Time.zone.local(2026, 9, 3, 23, 30) do
      expect do
        post facilitator_retrospective_action_items_path(context[:retro]), params: {
          action_item: {
            title: "Yesterday UTC",
            owner_id: context[:owner].id,
            due_on: "2026-09-02",
            status: "open"
          }
        }
      end.not_to(change { context[:team].action_items.count })

      expect do
        post facilitator_retrospective_action_items_path(context[:retro]), params: {
          action_item: {
            title: "Today UTC",
            owner_id: context[:owner].id,
            due_on: "2026-09-03",
            status: "open"
          }
        }
      end.to change { context[:team].action_items.where(title: "Today UTC").count }.by(1)
    end
  end

  it "records status history when status changes and requires a comment" do
    context = setup_item
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: { action_item: { status: "in_progress" } }
    expect(context[:item].reload).to be_open
    expect(context[:item].status_events).to be_empty
    expect(flash[:alert]).to include("must explain what changed")

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "   ")
    expect(context[:item].reload).to be_open
    expect(context[:item].status_events).to be_empty

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started implementation and completed the initial setup.")
    context[:item].reload
    expect(context[:item]).to be_in_progress
    event = context[:item].status_events.last
    expect(event.previous_status).to eq("open")
    expect(event.new_status).to eq("in_progress")
    expect(event.comment).to eq("Started implementation and completed the initial setup.")
    expect(event.actor).to eq(context[:facilitator])
    expect(event.created_at).to be_present

    get facilitator_retrospective_meeting_path(context[:retro])
    page = CGI.unescapeHTML(response.body)
    expect(page).to include("Activity")
    expect(page).to include("Open")
    expect(page).to include("In progress")
    expect(page).to include("Started implementation and completed the initial setup.")
    expect(page).to include(context[:facilitator].name)
    expect(page).to include("What changed?")
  end

  it "does not create history when status stays the same" do
    context = setup_item
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: {
      action_item: { status: "open", status_comment: "Should not be stored" }
    }

    expect(context[:item].reload).to be_open
    expect(context[:item].status_events).to be_empty
  end

  it "records each valid transition including cancellation" do
    context = setup_item
    sign_in(context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started implementation.")
    patch facilitator_action_item_path(context[:item]), params: status_change_params("ready_for_review", comment: "Implementation is complete.")
    patch facilitator_action_item_path(context[:item]), params: status_change_params("completed", comment: "Reviewed and merged.")

    expect(context[:item].reload.status_events.map { |event| [event.previous_status, event.new_status, event.comment] }).to eq(
      [
        ["open", "in_progress", "Started implementation."],
        ["in_progress", "ready_for_review", "Implementation is complete."],
        ["ready_for_review", "completed", "Reviewed and merged."]
      ]
    )

    other = context[:team].action_items.create!(
      title: "Cancel me",
      owner: context[:owner],
      created_by: context[:facilitator],
      due_on: Date.current + 2
    )
    patch facilitator_action_item_path(other), params: status_change_params("cancelled", comment: "The integration is no longer required.")
    event = other.reload.status_events.last
    expect(event.previous_status).to eq("open")
    expect(event.new_status).to eq("cancelled")
    expect(event.comment).to eq("The integration is no longer required.")
  end

  it "does not keep a status change if the history entry cannot be saved" do
    context = setup_item
    sign_in(context[:facilitator])
    allow_any_instance_of(ActionItemStatusEvent).to receive(:save!).and_raise(
      ActiveRecord::RecordInvalid.new(ActionItemStatusEvent.new)
    )

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Started implementation.")

    expect(context[:item].reload).to be_open
    expect(ActionItemStatusEvent.where(action_item: context[:item])).to be_empty
  end

  it "does not let an unauthorized user create status history" do
    context = setup_item
    sign_in(context[:other])

    patch facilitator_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Should not persist")
    patch participant_action_item_path(context[:item]), params: status_change_params("in_progress", comment: "Should not persist")

    expect(context[:item].reload).to be_open
    expect(context[:item].status_events).to be_empty
  end

  it "records the actual persisted transition when the item has already moved" do
    context = setup_item
    sign_in(context[:facilitator])
    context[:item].apply_status_change("in_progress", comment: "Started implementation.", actor: context[:facilitator])

    patch facilitator_action_item_path(context[:item]), params: status_change_params("completed", comment: "Reviewed and merged.")

    context[:item].reload
    expect(context[:item]).to be_completed
    expect(context[:item].status_events.last.previous_status).to eq("in_progress")
    expect(context[:item].status_events.last.new_status).to eq("completed")
  end
end
