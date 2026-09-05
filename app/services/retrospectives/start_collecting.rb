class Retrospectives::StartCollecting
  class Error < StandardError; end

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call
    invitation_tokens = {}

    Team.transaction do
      team = Team.lock.find(@retrospective.team_id)
      raise Error, "This team is archived." if team.archived?

      @retrospective.lock!
      raise Error, "Retrospective must be in draft" unless @retrospective.draft?
      raise Error, "Select at least one participant before sending invitations" if @retrospective.participations.none?
      raise Error, "this retrospective was already invited" if already_invited?

      @retrospective.participations.find_each do |participation|
        raw, digest = Token.generate
        participation.update!(invitation_token_digest: digest, invited_at: Time.current)
        invitation_tokens[participation.id] = raw
      end

      @retrospective.update!(status: :collecting, collecting_started_at: Time.current)
    end

    invitation_tokens.each do |participation_id, raw_token|
      SendRetroInvitationJob.perform_later(participation_id, raw_token)
    end
  end

  private

  def already_invited?
    @retrospective.participations.where.not(invited_at: nil).exists?
  end
end
