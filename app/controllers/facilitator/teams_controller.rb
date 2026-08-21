module Facilitator
  class TeamsController < BaseController
    def index
      @teams = current_user.facilitated_teams.order(:name)
    end

    def show
      @team = Team.find(params[:id])
      authorize!(@team, :update?)
      @memberships = @team.memberships.includes(:user).order(:role)
      @running_retrospective = @team.retrospectives.running.includes(:participations).order(:created_at).first
      @action_items = @team.action_items.includes(:owner).order(:due_on)
      @candidate_users = User.active.where.not(id: @team.user_ids).where.not(confirmed_at: nil).order(:name)
    end

    def new
      @team = Team.new
      authorize!(@team, :create?)
    end

    def create
      @team = Team.new(team_params)
      @team.created_by = current_user
      authorize!(@team, :create?)

      if @team.save
        @team.memberships.create!(user: current_user, role: :facilitator)
        redirect_to facilitator_team_path(@team), notice: "Team created."
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def team_params
      params.require(:team).permit(:name)
    end
  end
end
