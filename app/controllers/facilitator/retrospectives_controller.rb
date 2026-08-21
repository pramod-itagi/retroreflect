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
    end

    def create
      @team = Team.find(params[:team_id])
      @retrospective = @team.retrospectives.new(retrospective_params)
      @retrospective.created_by = current_user
      authorize!(@retrospective, :create?)

      if save_retrospective
        add_selected_participants
        redirect_to facilitator_retrospective_path(@retrospective), notice: "Retrospective created."
      else
        load_member_choices
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
      Retrospectives::StartCollecting.new(retrospective).call
      redirect_to facilitator_retrospective_path(retrospective), notice: "Invitations sent. Roster is frozen."
    rescue Retrospectives::StartCollecting::Error => e
      redirect_to facilitator_retrospective_path(retrospective), alert: e.message
    end

    def reveal
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :reveal?)
      Retrospectives::Reveal.new(retrospective).call
      redirect_to facilitator_retrospective_meeting_path(retrospective), notice: "Notes revealed anonymously."
    rescue Retrospectives::Reveal::Error => e
      redirect_to facilitator_retrospective_path(retrospective), alert: e.message
    end

    def close
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :close?)
      Retrospectives::Close.new(retrospective).call
      redirect_to facilitator_retrospective_path(retrospective), notice: "Retrospective closed."
    rescue Retrospectives::Close::Error => e
      redirect_to facilitator_retrospective_path(retrospective), alert: e.message
    end

    def cancel
      retrospective = Retrospective.find(params[:id])
      authorize!(retrospective, :cancel?)
      Retrospectives::Cancel.new(retrospective).call
      redirect_to facilitator_team_path(retrospective.team), notice: "Retrospective cancelled."
    rescue Retrospectives::Cancel::Error => e
      redirect_to facilitator_retrospective_path(retrospective), alert: e.message
    end

    private

    def retrospective_params
      params.require(:retrospective).permit(:title, :sprint_label, :scheduled_at)
    end

    def load_member_choices
      @members = @team.members.order(:name)
    end

    def save_retrospective
      Team.transaction do
        @team.lock!
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
