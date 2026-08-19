module Facilitator
  class ActionItemsController < BaseController
    def create
      @retrospective = Retrospective.find(params[:retrospective_id]) if params[:retrospective_id]
      @team = @retrospective&.team || Team.find(params[:team_id])
      @action_item = @team.action_items.new(action_item_params)
      @action_item.created_by = current_user
      @action_item.retrospective = @retrospective if @retrospective
      authorize!(@action_item, :create?)

      if @action_item.save
        redirect_back_or_to(facilitator_team_path(@team), notice: "Action item created.")
      else
        redirect_back_or_to(facilitator_team_path(@team), alert: @action_item.errors.full_messages.to_sentence)
      end
    end

    def update
      @action_item = ActionItem.find(params[:id])
      authorize!(@action_item, :update?)

      if @action_item.update(status_params)
        redirect_back_or_to(facilitator_team_path(@action_item.team), notice: "Action item updated.")
      else
        redirect_back_or_to(facilitator_team_path(@action_item.team), alert: @action_item.errors.full_messages.to_sentence)
      end
    end

    private

    def action_item_params
      params.require(:action_item).permit(:title, :description, :due_on, :owner_id, :status)
    end

    def status_params
      params.require(:action_item).permit(:status)
    end
  end
end
