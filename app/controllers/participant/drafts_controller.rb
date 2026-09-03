module Participant
  class DraftsController < BaseController
    before_action :set_retrospective_and_participation

    def create
      @draft = @participation.feedback_drafts.new(draft_params)
      @draft.retrospective = @retrospective
      authorize!(@draft, :create?)
      @operation_error_message = "We couldn't save your points. Please try again."

      if @draft.save
        redirect_to participant_retrospective_path(@retrospective), notice: "Draft saved."
      else
        fail_operation(
          @draft.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: participant_retrospective_path(@retrospective)
        )
      end
    end

    def save
      authorize!(@retrospective, :write_drafts?)
      @operation_error_message = "We couldn't save your points. Please try again."
      FeedbackDrafts::SaveBatch.new(
        participation: @participation,
        retrospective: @retrospective,
        drafts: drafts_attributes,
        new_drafts: new_drafts_attributes
      ).call
      redirect_to participant_retrospective_path(@retrospective), notice: "Draft saved."
    rescue ActiveRecord::RecordInvalid => e
      fail_operation(
        e.record.errors.full_messages.to_sentence.presence || @operation_error_message,
        fallback: participant_retrospective_path(@retrospective)
      )
    end

    def update
      @draft = @retrospective.feedback_drafts.find(params[:id])
      authorize!(@draft, :update?)
      @operation_error_message = "We couldn't save your points. Please try again."

      if @draft.update(draft_params)
        redirect_to participant_retrospective_path(@retrospective), notice: "Draft updated."
      else
        fail_operation(
          @draft.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: participant_retrospective_path(@retrospective)
        )
      end
    end

    def destroy
      @draft = @retrospective.feedback_drafts.find(params[:id])
      authorize!(@draft, :destroy?)
      @operation_error_message = "We couldn't remove that point. Please try again."
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

    def drafts_attributes
      raw = params[:drafts]
      return {} if raw.blank?

      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      hash.each_with_object({}) do |(id, attrs), assigned|
        assigned[id] = { body: attrs[:body] || attrs["body"] }
      end
    end

    def new_drafts_attributes
      raw = params[:new_drafts]
      return {} if raw.blank?

      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      hash.each_with_object({}) do |(category, bodies), assigned|
        next unless Retrospective::CATEGORIES.key?(category.to_s)

        assigned[category] = Array(bodies)
      end
    end
  end
end
