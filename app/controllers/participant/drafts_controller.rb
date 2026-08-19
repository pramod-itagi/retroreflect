module Participant
  class DraftsController < BaseController
    before_action :set_retrospective_and_participation

    def create
      @draft = @participation.feedback_drafts.new(draft_params)
      @draft.retrospective = @retrospective
      authorize!(@draft, :create?)

      if @draft.save
        redirect_to participant_retrospective_path(@retrospective), notice: "Draft saved."
      else
        redirect_to participant_retrospective_path(@retrospective), alert: @draft.errors.full_messages.to_sentence
      end
    end

    def update
      @draft = @retrospective.feedback_drafts.find(params[:id])
      authorize!(@draft, :update?)

      if @draft.update(draft_params)
        redirect_to participant_retrospective_path(@retrospective), notice: "Draft updated."
      else
        redirect_to participant_retrospective_path(@retrospective), alert: @draft.errors.full_messages.to_sentence
      end
    end

    def destroy
      @draft = @retrospective.feedback_drafts.find(params[:id])
      authorize!(@draft, :destroy?)
      @draft.destroy!
      redirect_to participant_retrospective_path(@retrospective), notice: "Draft removed."
    end

    private

    def set_retrospective_and_participation
      @retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(@retrospective, :participate?)
      @participation = @retrospective.participations.find_by!(user: current_user)
    end

    def draft_params
      params.require(:feedback_draft).permit(:category, :body)
    end
  end
end
