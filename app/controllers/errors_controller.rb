class ErrorsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  helper_method :error_retry_path

  def not_found
    render status: :not_found
  end

  def unprocessable
    @error_code = "422"
    render :internal_error, status: :unprocessable_entity
  end

  def internal_error
    @error_code ||= "500"
    render status: :internal_server_error
  end

  private

  def error_retry_path
    original = request.get_header("action_dispatch.original_request_uri")
    return original if original.present? && !internal_error_path?(original)

    request.fullpath
  end

  def internal_error_path?(path)
    path = path.to_s
    path.start_with?("/404", "/422", "/500")
  end
end
