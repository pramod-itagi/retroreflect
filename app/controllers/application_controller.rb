class ApplicationController < ActionController::Base
  include Authentication

  rescue_from NotAuthorized, with: :deny_access

  private

  def deny_access
    redirect_to root_path, alert: "You are not allowed to do that."
  end
end
