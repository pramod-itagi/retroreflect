module Participant
  class RetrospectivesController < BaseController
    def show
      @retrospective = Retrospective.find(params[:id])
      authorize!(@retrospective, :view_own_drafts?)
      @participation = @retrospective.participations.find_by!(user: current_user)
      @drafts = @participation.feedback_drafts.order(:created_at)
    end
  end
end
