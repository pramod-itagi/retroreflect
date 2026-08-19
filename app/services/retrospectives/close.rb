class Retrospectives::Close
  class Error < StandardError; end

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call
    raise Error, "retrospective must be discussing" unless @retrospective.discussing?

    @retrospective.update!(status: :closed, closed_at: Time.current)
  end
end
