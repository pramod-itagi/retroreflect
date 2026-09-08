class ConfirmationResendsController < ApplicationController
  SUCCESS_MESSAGE = "If an unconfirmed account exists for that email address, we've sent a new confirmation email.".freeze

  allow_unauthenticated_access only: %i[new create sent]

  def new
  end

  def create
    if AuthThrottle.blocked?(:confirmation_resend, request.remote_ip)
      redirect_to sent_confirmation_resends_path
      return
    end

    AuthThrottle.record!(:confirmation_resend, request.remote_ip)
    user = User.active.find_by(email: params[:email])
    if user && !user.confirmed?
      raw = user.issue_confirmation_token!
      UserMailer.confirmation(user, raw).deliver_later
    end
    redirect_to sent_confirmation_resends_path
  end

  def sent
    @message = SUCCESS_MESSAGE
  end
end
