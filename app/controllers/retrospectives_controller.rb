class RetrospectivesController < ApplicationController
  before_action :require_confirmed_email

  def index
    authorize!(Retrospective.new, :index?)

    scope = current_user.accessible_retrospectives.includes(:team, :participations)
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = apply_status_group(scope)
    scope = apply_search(scope)

    @active = scope.where(status: %w[collecting discussing]).order(updated_at: :desc, id: :desc)
    @drafts = scope.where(status: :draft).order(created_at: :desc, id: :desc)
    @previous = scope.where(status: %w[closed cancelled])
                     .order(Arel.sql("COALESCE(closed_at, cancelled_at, created_at) DESC"), id: :desc)
    @filter_teams = current_user.teams.order(:name)
    @facilitated_team_ids = current_user.facilitated_teams.pluck(:id)
  end

  private

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
