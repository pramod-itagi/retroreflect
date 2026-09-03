module Participant
  class SubmissionsController < BaseController
    before_action :set_retrospective

    def new
      authorize!(@retrospective, :submit_notes?)
      redirect_to participant_retrospective_path(@retrospective)
    end

    def create
      authorize!(@retrospective, :submit_notes?)
      participation = @retrospective.participations.find_by!(user: current_user)
      @operation_error_message = "We couldn't submit your feedback. Please try again."

      if participation.submit_responses
        redirect_to participant_retrospective_path(@retrospective), notice: "Responses submitted."
      else
        fail_operation(
          participation.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: participant_retrospective_path(@retrospective)
        )
      end
    end

    private

    def set_retrospective
      @retrospective = Retrospective.find(params[:retrospective_id])
    end
  end
end
