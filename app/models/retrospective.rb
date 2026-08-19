class Retrospective < ApplicationRecord
  SPRINT_NUMBERS = (1..40)
  SPRINT_LABELS = SPRINT_NUMBERS.map { |number| "Sprint #{number}" }.freeze

  CATEGORIES = {
    "went_well" => "What went well",
    "did_not_go_well" => "What didn't go well",
    "continue" => "What should we continue",
    "improve" => "What should we improve"
  }.freeze

  belongs_to :team
  belongs_to :created_by, class_name: "User"
  has_many :participations, dependent: :destroy
  has_many :feedback_drafts, dependent: :destroy
  has_many :feedback_items, dependent: :destroy
  has_many :action_items, dependent: :nullify

  enum :status, {
    draft: "draft",
    collecting: "collecting",
    discussing: "discussing",
    closed: "closed",
    cancelled: "cancelled"
  }, validate: true

  validates :title, presence: true
  validates :sprint_label, inclusion: { in: SPRINT_LABELS }, allow_blank: true

  scope :active, -> { where.not(status: :cancelled) }

  def roster_frozen?
    collecting? || discussing? || closed? || cancelled?
  end

  def notes_writable?
    collecting?
  end

  def revealed?
    discussing? || closed?
  end
end
