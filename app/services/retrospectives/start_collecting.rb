class Retrospectives::StartCollecting
  class Error < StandardError; end

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call
    raise Error, "retrospective must be in draft" unless @retrospective.draft?
    raise Error, "select at least one participant" if @retrospective.participations.none?

    invitation_tokens = {}

    Retrospective.transaction do
      @retrospective.participations.find_each do |participation|
        raise Error, "this retrospective was already invited" if participation.invited_at.present?

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
end
