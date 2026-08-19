module Participant
  class ActionItemsController < BaseController
    def index
      @action_items = current_user.owned_action_items.includes(:team, :retrospective).order(:due_on)
    end

    def update
      @action_item = ActionItem.find(params[:id])
      authorize!(@action_item, :update_as_owner?)
      new_status = status_params[:status]
      raise NotAuthorized unless @action_item.owner_may_transition_to?(new_status)

      if @action_item.update(status: new_status)
        redirect_to participant_action_items_path, notice: "Action item updated."
      else
        redirect_to participant_action_items_path, alert: @action_item.errors.full_messages.to_sentence
      end
    end

    private

    def status_params
      params.require(:action_item).permit(:status)
    end
  end
end
