class PasswordResetsController < ApplicationController
  allow_unauthenticated_access only: %i[new create edit update]

  def new
  end

  def create
    if AuthThrottle.blocked?(:password_reset, request.remote_ip)
      redirect_to new_session_path, notice: "If that account exists, we sent reset instructions."
      return
    end

    AuthThrottle.record!(:password_reset, request.remote_ip)
    user = User.active.find_by(email: params[:email])
    if user
      raw = user.issue_password_reset_token!
      UserMailer.password_reset(user, raw).deliver_later
    end
    redirect_to new_session_path, notice: "If that account exists, we sent reset instructions."
  end

  def edit
    @user = User.find_for_password_reset(params[:token])
    redirect_to new_password_reset_path, alert: "Reset link is invalid or expired." unless @user
  end

  def update
    @user = User.find_for_password_reset(params[:token])
    unless @user
      redirect_to new_password_reset_path, alert: "Reset link is invalid or expired."
      return
    end

    if @user.update(password_params)
      @user.clear_password_reset_token!
      start_session_for(@user)
      redirect_to root_path, notice: "Password updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
