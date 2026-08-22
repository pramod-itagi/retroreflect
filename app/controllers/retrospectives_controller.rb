class RetrospectivesController < ApplicationController
  before_action :require_confirmed_email

  def index
    authorize!(Retrospective.new, :index?)

    scope = filtered_retrospectives
    @active = scope.where(status: %w[collecting discussing]).order(updated_at: :desc, id: :desc)
    @drafts = scope.where(status: :draft).order(created_at: :desc, id: :desc)
    @previous = scope.where(status: %w[closed cancelled])
                     .order(Arel.sql("COALESCE(closed_at, cancelled_at, created_at) DESC"), id: :desc)
    @filter_teams = Team.where(id: current_user.memberships.select(:team_id)).order(:name)
    @facilitated_team_ids = current_user.memberships.facilitator.pluck(:team_id)
  end

  private

  def filtered_retrospectives
    scope = current_user.accessible_retrospectives.includes(:team, :participations)
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    apply_search(apply_status_group(scope))
  end

  def apply_status_group(scope)
    case params[:status]
    when "active" then scope.where(status: %w[collecting discussing])
    when "draft" then scope.where(status: :draft)
    when "previous" then scope.where(status: %w[closed cancelled])
    else scope
    end
  end

  def apply_search(scope)
    query = params[:q].to_s.strip
    return scope if query.blank?

    pattern = "%#{Retrospective.sanitize_sql_like(query)}%"
    scope.where("retrospectives.title LIKE ? OR retrospectives.sprint_label LIKE ?", pattern, pattern)
  end
end
