module Facilitator
  class TeamsController < BaseController
    def index
      @teams = current_user.facilitated_teams.where(archived_at: nil).order(:name)
    end

    def show
      @team = Team.find(params[:id])
      authorize!(@team, :update?)
      @memberships = @team.current_memberships.includes(:user).order(:role)
      @running_retrospective = @team.retrospectives.running.includes(:participations).order(:created_at).first
      @action_items = @team.action_items.unresolved.includes(:owner).order(:due_on, :title)
      @candidate_users = User.active.where.not(id: @team.user_ids).where.not(confirmed_at: nil).order(:name)
    end
  end
end
