module Facilitator
  class ActionItemsController < BaseController
    def index
      @team = Team.find(params[:team_id])
      authorize!(@team, :view_action_items?)
      @action_items = @team.action_items.includes(:owner, :team, status_events: :actor).order(:due_on, :id)
      @can_show_team = TeamPolicy.new(current_user, @team).show?
    end

    def create
      @retrospective = Retrospective.find(params[:retrospective_id]) if params[:retrospective_id]
      @team = @retrospective&.team || Team.find(params[:team_id])
      @action_item = @team.action_items.new(action_item_params)
      @action_item.created_by = current_user
      @action_item.status = "open"
      @action_item.retrospective = @retrospective if @retrospective
      authorize!(@action_item, :create?)
      @operation_error_message = "We couldn't add that action item. Please try again."

      if @action_item.persist_for_current_retrospective(authorized_by: current_user)
        redirect_back_or_to(facilitator_team_path(@team), notice: "Action item created.")
      else
        fail_operation(
          @action_item.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: facilitator_team_path(@team)
        )
      end
    end

    def update
      @action_item = ActionItem.find(params[:id])
      authorize!(@action_item, :update?)
      @operation_error_message = "We couldn't update that action item. Please try again."

      if @action_item.apply_status_change(status_params[:status], comment: status_params[:status_comment], actor: current_user)
        redirect_back_or_to(facilitator_team_path(@action_item.team), notice: "Action item updated.")
      else
        fail_operation(
          @action_item.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: facilitator_team_path(@action_item.team)
        )
      end
    end

    private

    def action_item_params
      params.require(:action_item).permit(:title, :description, :due_on, :owner_id)
    end

    def status_params
      params.require(:action_item).permit(:status, :status_comment)
    end
  end
end
