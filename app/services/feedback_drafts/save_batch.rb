class FeedbackDrafts::SaveBatch
  def initialize(participation:, retrospective:, drafts:, new_drafts:)
    @participation = participation
    @retrospective = retrospective
    @drafts = drafts
    @new_drafts = new_drafts
  end

  def call
    FeedbackDraft.transaction do
      locked = Retrospective.lock.find(@retrospective.id)
      @retrospective = locked
      @participation.retrospective = locked
      update_existing
      create_new
    end
  end

  private

  def update_existing
    @drafts.each do |id, attrs|
      body = attrs[:body].to_s.strip
      next if body.blank?

      draft = @participation.feedback_drafts.find_by(id: id)
      next if draft.blank? || draft.body == body

      draft.update!(body: body)
    end
  end

  def create_new
    @new_drafts.each do |category, bodies|
      next unless Retrospective::CATEGORIES.key?(category.to_s)

      Array(bodies).each do |body|
        body = body.to_s.strip
        next if body.blank?

        @participation.feedback_drafts.create!(
          retrospective: @retrospective,
          category: category,
          body: body
        )
      end
    end
  end
end
