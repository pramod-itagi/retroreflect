module Facilitator
  class RetrospectivesController < BaseController
    def new
      @team = Team.find(params[:team_id])
      authorize!(@team, :update?)
      if @team.running_retrospective.present?
        redirect_to facilitator_team_path(@team), alert: Retrospective::ONE_ACTIVE_MESSAGE
        return
      end

      @retrospective = @team.retrospectives.new
      load_member_choices
      load_identity_preview
    end

    def create
      @team = Team.find(params[:team_id])
      @retrospective = @team.retrospectives.new
      @retrospective.created_by = current_user
      authorize!(@retrospective, :create?)
      @operation_error_message = "We couldn't create the retrospective. Please try again."

      if save_retrospective
        add_selected_participants
        redirect_to facilitator_retrospective_path(@retrospective), notice: "Retrospective created."
      else
        load_member_choices
        load_identity_preview
        render :new, status: :unprocessable_content
      end
    end

    def show
      @retrospective = Retrospective.find(params[:id])
      authorize!(@retrospective, :view_roster?)
      @team = @retrospective.team
      @participations = @retrospective.participations.includes(:user)
      @submitted_count = @participations.count(&:submitted?)
      @available_members = @team.members.where.not(id: @participations.select(:user_id)).order(:name)
    end

    def start_collecting
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :start_collecting?)
      @operation_error_message = "We couldn't send invitations. Please try again."
      Retrospectives::StartCollecting.new(retrospective).call
      redirect_to facilitator_retrospective_path(retrospective), notice: "Invitations sent. Roster is frozen."
    rescue Retrospectives::StartCollecting::Error => e
      fail_operation(e.message, fallback: facilitator_retrospective_path(retrospective))
    end

    def reveal
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :reveal?)
      @operation_error_message = "We couldn't reveal notes. Please try again."
      Retrospectives::Reveal.new(retrospective).call
      redirect_to facilitator_retrospective_meeting_path(retrospective), notice: "Notes revealed anonymously."
    rescue Retrospectives::Reveal::Error => e
      fail_operation(e.message, fallback: facilitator_retrospective_path(retrospective))
    end

    def close
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :close?)
      @operation_error_message = "We couldn't close the retrospective. Please try again."
      Retrospectives::Close.new(retrospective).call
      redirect_to facilitator_retrospective_path(retrospective), notice: "Retrospective closed."
    rescue Retrospectives::Close::Error => e
      fail_operation(e.message, fallback: facilitator_retrospective_path(retrospective))
    end

    def cancel
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :cancel?)
      @operation_error_message = "We couldn't cancel the retrospective. Please try again."
      Retrospectives::Cancel.new(retrospective).call(cancellation_reason: params[:cancellation_reason])
      redirect_to facilitator_retrospective_path(retrospective), notice: "Retrospective cancelled."
    rescue Retrospectives::Cancel::Error => e
      fail_operation(e.message, fallback: facilitator_retrospective_path(retrospective))
    rescue ActiveRecord::RecordInvalid => e
      fail_operation(e.record.errors.full_messages.to_sentence, fallback: facilitator_retrospective_path(retrospective))
    end

    private

    def load_member_choices
      @members = @team.members.order(:name)
    end

    def load_identity_preview
      if @retrospective.sprint_number.present?
        @sprint_identifier = @retrospective.sprint_label
        @generated_title = @retrospective.title
      else
        identity = Retrospective.generated_identity_for(@team)
        @sprint_identifier = identity[:sprint_label]
        @generated_title = identity[:title]
      end
    end

    def save_retrospective
      Team.transaction do
        @team.lock!
        @retrospective.assign_attributes(Retrospective.generated_identity_for(@team))
        @retrospective.save
      end
    rescue ActiveRecord::RecordNotUnique
      @retrospective.errors.add(:base, Retrospective::ONE_ACTIVE_MESSAGE)
      false
    end

    def add_selected_participants
      selected_ids = Array(params[:participant_ids]).compact_blank
      @team.members.where(id: selected_ids).find_each do |user|
        @retrospective.participations.create!(user: user)
      end
    end
  end
end
