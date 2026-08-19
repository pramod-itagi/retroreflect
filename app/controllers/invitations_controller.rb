class InvitationsController < ApplicationController
  def show
    participation = Participation.find_by(invitation_token_digest: Token.digest(params[:token].to_s))
    return deny("Invitation is invalid.") if participation.blank?
    return deny("This invitation is for a different account.") if participation.user_id != current_user.id
    return deny("Confirm your email to continue.") unless current_user.confirmed?
    return deny("Invitation has expired.") if participation.invitation_expired?
    return deny("This retrospective is no longer open.") unless participation.retrospective.collecting?

    already_accepted = participation.invitation_accepted?
    participation.accept_invitation!

    redirect_to participant_retrospective_path(participation.retrospective),
                notice: already_accepted ? "You already accepted this invitation." : "Invitation accepted."
  end

  private

  def deny(message)
    redirect_to root_path, alert: message
  end
end
