module Facilitator
  class TeamsController < BaseController
    def index
      @teams = current_user.workspace_teams.includes(:current_memberships, :retrospectives).order(:name)
      @roles_by_team_id = current_user.current_memberships
                                      .where(team_id: @teams.map(&:id))
                                      .pluck(:team_id, :role)
                                      .to_h
    end

    def show
      @team = Team.find(params[:id])
      authorize!(@team, :show?)
      @can_manage_team = TeamPolicy.new(current_user, @team).update?
      @memberships = @team.current_memberships.includes(:user).order(:role)
      @running_retrospective = @team.retrospectives.running.includes(:participations).order(:created_at).first
      @action_items = @team.action_items.unresolved.includes(:owner).order(:due_on, :title)
      @has_action_item_history = @team.action_items.exists?
      @candidate_users = if @can_manage_team
                           User.active.where.not(id: @team.user_ids).where.not(confirmed_at: nil).order(:name)
                         else
                           User.none
                         end
    end
  end
end
