class HealthController < ApplicationController
  allow_unauthenticated_access only: %i[show live]

  def show
    @checked_at = Time.zone.now
    @environment = Rails.env
    @database_healthy = database_healthy?
    @overall_healthy = @database_healthy

    render status: (@overall_healthy ? :ok : :service_unavailable)
  end

  def live
    render plain: "OK", content_type: "text/plain"
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.select_value("SELECT 1").present?
  rescue StandardError => e
    Rails.logger.error("[health] database check failed: #{e.class}")
    false
  end
end
