class SendRetroInvitationJob < ApplicationJob
  queue_as :default

  def perform(participation_id, raw_token)
    participation = Participation.find_by(id: participation_id)
    return if participation.blank?
    return unless participation.retrospective.collecting?
    return if participation.invitation_expired?

    InvitationMailer.retrospective_invitation(participation, raw_token).deliver_now
  end
end
