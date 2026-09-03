module Facilitator
  class ParticipationsController < BaseController
    def create
      retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(retrospective, :manage_roster?)
      @operation_error_message = "We couldn't add that person to the roster. Please try again."
      if params[:user_id].blank?
        fail_operation("Select a team member.", fallback: facilitator_retrospective_path(retrospective))
        return
      end

      user = User.active.find(params[:user_id])
      participation = retrospective.participations.new(user: user)
      @operation_error_message = "We couldn't add #{user.display_name} to the roster. Please try again."

      if participation.save
        redirect_to facilitator_retrospective_path(retrospective), notice: "#{user.display_name} added to the roster."
      else
        fail_operation(
          participation.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: facilitator_retrospective_path(retrospective)
        )
      end
    end

    def destroy
      retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(retrospective, :manage_roster?)
      participation = retrospective.participations.find(params[:id])
      @operation_error_message = "We couldn't remove that person from the roster. Please try again."
      participation.destroy!
      redirect_to facilitator_retrospective_path(retrospective), notice: "Removed from roster."
    end
  end
end
