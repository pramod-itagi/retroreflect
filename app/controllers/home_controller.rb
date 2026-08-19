class HomeController < ApplicationController
  def show
    @facilitated_teams = current_user.facilitated_teams.order(:name)
    @member_teams = current_user.member_teams.order(:name)
    @collecting_retrospectives = Retrospective
                                 .collecting
                                 .joins(:participations)
                                 .where(participations: { user_id: current_user.id })
                                 .includes(:team)
                                 .order(:title)
    @owned_action_items = current_user.owned_action_items.includes(:team).order(:due_on)
  end
end
