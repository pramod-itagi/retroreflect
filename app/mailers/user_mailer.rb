class UserMailer < ApplicationMailer
  def confirmation(user, raw_token)
    @user = user
    @url = email_confirmation_url(token: raw_token)
    mail(to: user.email, subject: "Confirm your Retroreflect account")
  end

  def password_reset(user, raw_token)
    @user = user
    @url = edit_password_reset_url(token: raw_token)
    mail(to: user.email, subject: "Reset your Retroreflect password")
  end
end
