class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      raw = @user.issue_confirmation_token!
      UserMailer.confirmation(@user, raw).deliver_later
      redirect_to new_session_path, notice: "Check your email to confirm your account."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
