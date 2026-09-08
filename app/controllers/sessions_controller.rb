class SessionsController < ApplicationController
  UNCONFIRMED_ALERT = "Confirm your email before signing in.".freeze

  allow_unauthenticated_access only: %i[new create]
  helper_method :unconfirmed_sign_in_attempt?

  def new
    redirect_to root_path if authenticated?
  end

  def create
    if AuthThrottle.blocked?(:login, request.remote_ip)
      flash.now[:alert] = AuthThrottle::TOO_MANY_ATTEMPTS
      render :new, status: :unprocessable_content
      return
    end

    user = User.active.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      unless user.confirmed?
        redirect_to new_session_path, alert: UNCONFIRMED_ALERT
        return
      end

      start_session_for(user)
      redirect_to(session.delete(:return_to).presence || root_path, notice: "Signed in.")
    else
      AuthThrottle.record!(:login, request.remote_ip)
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Signed out."
  end

  private

  def unconfirmed_sign_in_attempt?
    flash[:alert] == UNCONFIRMED_ALERT
  end
end
