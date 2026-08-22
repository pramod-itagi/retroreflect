class Retrospective < ApplicationRecord
  self.ignored_columns += %w[running_team_id]

  SPRINT_NUMBERS = (1..40)
  SPRINT_LABELS = SPRINT_NUMBERS.map { |number| "Sprint #{number}" }.freeze
  RUNNING_STATUSES = %w[draft collecting discussing].freeze
  IN_SESSION_STATUSES = %w[collecting discussing].freeze
  ONE_ACTIVE_MESSAGE = "This team already has an active retrospective. Close it before creating another.".freeze

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
  validate :team_must_not_have_another_running_retrospective, on: :create

  scope :active, -> { where.not(status: :cancelled) }
  scope :running, -> { where(status: RUNNING_STATUSES) }
  scope :in_session, -> { where(status: IN_SESSION_STATUSES) }

  def running?
    RUNNING_STATUSES.include?(status)
  end

  def roster_frozen?
    collecting? || discussing? || closed? || cancelled?
  end

  def notes_writable?
    collecting?
  end

  def revealed?
    discussing? || closed?
  end

  def any_submissions?
    participations.submitted.exists?
  end

  def participant_count
    participations.loaded? ? participations.size : participations.count
  end

  def submitted_count
    if participations.loaded?
      participations.count(&:submitted?)
    else
      participations.submitted.count
    end
  end

  private

  def team_must_not_have_another_running_retrospective
    return if team.blank? || !running?
    return unless team.retrospectives.running.exists?

    errors.add(:base, ONE_ACTIVE_MESSAGE)
  end
end
