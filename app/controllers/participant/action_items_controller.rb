module Participant
  class ActionItemsController < BaseController
    def index
      @action_items = current_user.owned_action_items.includes(:team, :retrospective, status_events: :actor).order(:due_on)
    end

    def update
      @action_item = ActionItem.find(params[:id])
      authorize!(@action_item, :update_as_owner?)
      new_status = status_params[:status]
      raise NotAuthorized unless @action_item.owner_may_transition_to?(new_status)
      @operation_error_message = "We couldn't update that action item. Please try again."

      if @action_item.apply_status_change(new_status, comment: status_params[:status_comment], actor: current_user)
        redirect_to participant_action_items_path, notice: "Action item updated."
      else
        fail_operation(
          @action_item.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: participant_action_items_path
        )
      end
    end

    private

    def status_params
      params.require(:action_item).permit(:status, :status_comment)
    end
  end
end
