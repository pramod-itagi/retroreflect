class InvitationMailer < ApplicationMailer
  def retrospective_invitation(participation, raw_token)
    @user = participation.user
    @retrospective = participation.retrospective
    @url = invitation_url(token: raw_token)
    mail(to: @user.email, subject: "You're invited to #{@retrospective.title}")
  end
end
