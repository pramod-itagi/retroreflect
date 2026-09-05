# Copies submitted draft bodies into anonymous feedback_items, then deletes drafts.
# Never copies participation_id, user_id, or draft id onto published notes.
# Shuffle within each category so discussion order is not submission order.
class Retrospectives::Reveal
  class Error < StandardError; end

  NO_SUBMISSIONS_MESSAGE = [
    "Cannot reveal feedback yet. No participants have submitted any feedback.",
    "At least one participant must submit feedback before the retrospective can be revealed."
  ].join(" ").freeze

  def initialize(retrospective)
    @retrospective = retrospective
  end

  def call
    Retrospective.transaction do
      @retrospective.lock!
      return if @retrospective.revealed?

      raise Error, "retrospective must be collecting" unless @retrospective.collecting?
      raise Error, NO_SUBMISSIONS_MESSAGE unless @retrospective.any_submissions?

      position = 0
      drafts_by_category = submitted_drafts.group_by { |draft| draft.category.to_s }

      Retrospective::CATEGORIES.each_key do |category|
        Array(drafts_by_category[category]).shuffle.each do |draft|
          position += 1
          FeedbackItem.create!(
            retrospective: @retrospective,
            category: draft.category,
            body: draft.body,
            reveal_position: position
          )
        end
      end

      @retrospective.feedback_drafts.delete_all
      @retrospective.update!(status: :discussing, revealed_at: Time.current)
    end
  end

  private

  def submitted_drafts
    @retrospective.feedback_drafts.joins(:participation).merge(Participation.submitted)
  end
end
