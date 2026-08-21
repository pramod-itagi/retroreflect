class HomeController < ApplicationController
  def show
    @facilitated_team_ids = current_user.facilitated_teams.pluck(:id)
    @teams = current_user.teams.includes(:memberships, retrospectives: :participations).order(:name)
    @draft_retrospectives = Retrospective.draft
                                         .where(team_id: @facilitated_team_ids)
                                         .includes(:team, :participations)
                                         .order(created_at: :desc)
    @attention_action_items = current_user.owned_action_items
                                          .where.not(status: ActionItem::TERMINAL_STATUSES)
                                          .includes(:team)
                                          .order(:due_on)
                                          .limit(8)
  end
end
