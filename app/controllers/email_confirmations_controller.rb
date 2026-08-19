class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    user = User.find_for_email_confirmation(params[:token])
    if user
      user.confirm!
      start_session_for(user)
      redirect_to root_path, notice: "Email confirmed."
    else
      redirect_to new_session_path, alert: "Confirmation link is invalid or expired."
    end
  end
end
