module Facilitator
  class MeetingsController < BaseController
    def show
      @retrospective = Retrospective.find(params[:retrospective_id])
      authorize!(@retrospective, :view_meeting?)
      @participations = @retrospective.participations.includes(:user)
      @submitted_count = @retrospective.participations.where.not(submitted_at: nil).count
      @items_by_category = FeedbackItem.for_meeting(@retrospective).group_by { |item| item.category.to_s }
      @team = @retrospective.team
      @action_items = @retrospective.action_items.includes(:owner, status_events: :actor).order(:due_on)
      @owners = @team.users.active.order(:name)
    end
  end
end
