module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_user, :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_user
    Current.user ||= User.active.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    return if authenticated?

    session[:return_to] = request.fullpath if request.get?
    redirect_to new_session_path, alert: "Please sign in."
  end

  def require_confirmed_email
    return if current_user&.confirmed?

    redirect_to root_path, alert: "Confirm your email to continue."
  end

  def start_session_for(user)
    return_to = session[:return_to]
    reset_session
    session[:user_id] = user.id
    session[:return_to] = return_to if return_to.present?
    Current.user = user
  end

  def terminate_session
    reset_session
    Current.user = nil
  end

  def authorize!(record, query)
    policy_class = "#{record.class.name}Policy".constantize
    policy = policy_class.new(current_user, record)
    raise NotAuthorized unless policy.public_send(query)
  end
end
