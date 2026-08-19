# Published anonymous notes. These rows are created only at reveal.
# They must never gain a user, participation, or draft association.
class FeedbackItem < ApplicationRecord
  self.primary_key = "id"
  self.implicit_order_column = "reveal_position"

  belongs_to :retrospective

  enum :category, {
    went_well: "went_well",
    did_not_go_well: "did_not_go_well",
    continue: "continue",
    improve: "improve"
  }, validate: true

  validates :body, presence: true
  validates :reveal_position, presence: true

  before_validation :assign_id, on: :create

  def self.for_meeting(retrospective)
    where(retrospective: retrospective).order(:reveal_position)
  end

  private

  def assign_id
    self.id ||= SecureRandom.uuid
  end
end
