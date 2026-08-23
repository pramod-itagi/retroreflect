module Participant
  class SubmissionsController < BaseController
    before_action :set_retrospective

    def new
      authorize!(@retrospective, :submit_notes?)
    end

    def create
      authorize!(@retrospective, :submit_notes?)
      participation = @retrospective.participations.find_by!(user: current_user)

      if participation.submit_responses
        redirect_to participant_retrospective_path(@retrospective), notice: "Responses submitted."
      else
        redirect_to participant_retrospective_path(@retrospective), alert: participation.errors.full_messages.to_sentence
      end
    end

    private

    def set_retrospective
      @retrospective = Retrospective.find(params[:retrospective_id])
    end
  end
end
