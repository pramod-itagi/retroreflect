module Participant
  class SubmissionsController < BaseController
    def create
      retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(retrospective, :submit_notes?)
      participation = retrospective.participations.find_by!(user: current_user)

      if participation.submit_responses
        redirect_to participant_retrospective_path(retrospective), notice: "Responses submitted."
      else
        redirect_to participant_retrospective_path(retrospective), alert: participation.errors.full_messages.to_sentence
      end
    end
  end
end
