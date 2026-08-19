class Retrospectives::Cancel
  class Error < StandardError; end

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call
    raise Error, "can only cancel a draft or collecting retrospective" unless @retrospective.draft? || @retrospective.collecting?

    Retrospective.transaction do
      @retrospective.feedback_drafts.delete_all
      @retrospective.update!(status: :cancelled, cancelled_at: Time.current)
    end
  end
end
