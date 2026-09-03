module OperationErrors
  extend ActiveSupport::Concern

  UNEXPECTED_OPERATION_MESSAGES = {
    "memberships#destroy" => "We couldn't remove that person from the team. Please try again.",
    "memberships#update" => "We couldn't update that member. Please try again.",
    "memberships#create" => "We couldn't add that person to the team. Please try again.",
    "submissions#create" => "We couldn't submit your feedback. Please try again.",
    "drafts#save" => "We couldn't save your points. Please try again.",
    "drafts#create" => "We couldn't save your points. Please try again.",
    "drafts#update" => "We couldn't save your points. Please try again.",
    "drafts#destroy" => "We couldn't remove that point. Please try again.",
    "action_items#create" => "We couldn't add that action item. Please try again.",
    "action_items#update" => "We couldn't update that action item. Please try again.",
    "teams#create" => "We couldn't create the team. Please try again.",
    "team_archives#create" => "We couldn't archive this team. Please try again.",
    "retrospectives#create" => "We couldn't create the retrospective. Please try again.",
    "retrospectives#start_collecting" => "We couldn't send invitations. Please try again.",
    "retrospectives#reveal" => "We couldn't reveal notes. Please try again.",
    "retrospectives#close" => "We couldn't close the retrospective. Please try again.",
    "retrospectives#cancel" => "We couldn't cancel the retrospective. Please try again.",
    "participations#create" => "We couldn't add that person to the roster. Please try again.",
    "participations#destroy" => "We couldn't remove that person from the roster. Please try again.",
    "admins#create" => "We couldn't add that system admin. Please try again.",
    "admins#destroy" => "We couldn't remove that system admin. Please try again."
  }.freeze

  included do
    rescue_from StandardError, with: :handle_unexpected_operation_error
  end

  private

  def fail_operation(message, fallback:, title: nil)
    if turbo_stream_request?
      render_operation_error_stream(message, title: title)
    else
      redirect_back fallback_location: fallback, allow_other_host: false, alert: message
    end
  end

  def handle_unexpected_operation_error(exception)
    raise unless operation_request?
    raise if reraise_operation_error?(exception)
    raise if @handling_operation_error

    @handling_operation_error = true
    Rails.logger.error(
      "[operation] #{exception.class}: #{exception.message}\n#{Array(exception.backtrace).first(8).join("\n")}"
    )

    fail_operation(
      unexpected_operation_message,
      fallback: operation_error_fallback,
      title: "Something went wrong"
    )
  end

  def reraise_operation_error?(exception)
    exception.is_a?(NotAuthorized) ||
      exception.is_a?(ActiveRecord::RecordNotFound) ||
      exception.is_a?(ActionController::InvalidAuthenticityToken) ||
      exception.is_a?(ActionController::ParameterMissing) ||
      exception.is_a?(AbstractController::ActionNotFound)
  end

  def operation_request?
    return false if is_a?(ErrorsController)

    request.post? || request.patch? || request.put? || request.delete?
  end

  def turbo_stream_request?
    request.format.turbo_stream? || request.headers["Accept"].to_s.include?("text/vnd.turbo-stream.html")
  end

  def unexpected_operation_message
    @operation_error_message.presence ||
      UNEXPECTED_OPERATION_MESSAGES["#{controller_name}##{action_name}"] ||
      "We couldn't complete your request. Please try again."
  end

  def operation_error_fallback
    request.referer.presence || root_path
  end

  def render_operation_error_stream(message, title: nil)
    render turbo_stream: turbo_stream.prepend(
      "app-alerts",
      partial: "shared/app_alert",
      locals: { kind: "error", title: title, message: message, messages: nil, autohide: true }
    ), status: :unprocessable_content
  end
end
