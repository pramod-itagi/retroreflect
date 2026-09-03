class ApplicationController < ActionController::Base
  include Authentication
  include OperationErrors

  rescue_from NotAuthorized, with: :deny_access
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def deny_access
    redirect_to root_path, alert: "You are not allowed to do that."
  end

  def render_not_found
    render "errors/not_found", status: :not_found
  end
end
