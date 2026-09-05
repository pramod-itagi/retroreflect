class FeedbackDraft < ApplicationRecord
  belongs_to :retrospective
  belongs_to :participation

  enum :category, {
    went_well: "went_well",
    did_not_go_well: "did_not_go_well",
    continue: "continue",
    improve: "improve"
  }, validate: true

  validates :body, presence: true, length: { maximum: 2000 }
  validate :responses_must_be_editable
  validate :participation_belongs_to_retrospective

  before_validation :lock_parent_retrospective
  before_destroy :lock_parent_retrospective
  before_destroy :ensure_responses_editable

  private

  def lock_parent_retrospective
    return if retrospective_id.blank?

    self.retrospective = Retrospective.lock.find(retrospective_id)
  end

  def responses_must_be_editable
    return if editable?

    errors.add(:base, "notes can only be written while collecting, before you submit")
  end

  def ensure_responses_editable
    throw :abort unless editable?
  end

  def editable?
    retrospective&.collecting? && !participation&.submitted?
  end

  def participation_belongs_to_retrospective
    return if participation.blank? || retrospective.blank?
    return if participation.retrospective_id == retrospective_id

    errors.add(:participation, "does not belong to this retrospective")
  end
end
