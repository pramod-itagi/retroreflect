class Retrospectives::Cancel
  class Error < StandardError; end

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call(cancellation_reason: nil)
    Retrospective.transaction do
      @retrospective.lock!
      raise Error, "can only cancel a draft or collecting retrospective" unless @retrospective.draft? || @retrospective.collecting?

      @retrospective.feedback_drafts.delete_all
      @retrospective.update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancellation_reason: cancellation_reason.to_s.strip.presence
      )
    end
  end
end
