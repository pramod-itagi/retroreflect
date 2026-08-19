module Facilitator
  class ParticipationsController < BaseController
    def create
      retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(retrospective, :manage_roster?)
      if params[:user_id].blank?
        redirect_to facilitator_retrospective_path(retrospective), alert: "Select a team member."
        return
      end

      user = User.active.find(params[:user_id])
      participation = retrospective.participations.new(user: user)

      if participation.save
        redirect_to facilitator_retrospective_path(retrospective), notice: "#{user.display_name} added to the roster."
      else
        redirect_to facilitator_retrospective_path(retrospective), alert: participation.errors.full_messages.to_sentence
      end
    end

    def destroy
      retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(retrospective, :manage_roster?)
      participation = retrospective.participations.find(params[:id])
      participation.destroy!
      redirect_to facilitator_retrospective_path(retrospective), notice: "Removed from roster."
    end
  end
end
