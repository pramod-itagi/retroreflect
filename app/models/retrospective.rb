class Retrospective < ApplicationRecord
  self.ignored_columns += %w[running_team_id]

  SPRINT_LABEL_NUMBER = /\ASprint (\d+)(?: \((\d{4})\))?\z/
  CANCELLATION_REASON_MAX = 2_000
  RUNNING_STATUSES = %w[draft collecting discussing].freeze
  IN_SESSION_STATUSES = %w[collecting discussing].freeze
  ONE_ACTIVE_MESSAGE = "This team already has an active retrospective. Close it before creating another.".freeze

  CATEGORIES = {
    "went_well" => "What went well",
    "did_not_go_well" => "What didn't go well",
    "continue" => "What to continue",
    "improve" => "What to improve"
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
  validates :sprint_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sprint_year, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sprint_number, uniqueness: { scope: :team_id }, allow_nil: true
  validates :cancellation_reason, length: { maximum: CANCELLATION_REASON_MAX }, allow_blank: true
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

  def self.calendar_year(at = Time.zone.now)
    at.in_time_zone(Time.zone).year
  end

  def self.sprint_identifier(number, year)
    "Sprint #{number} (#{year})"
  end

  def self.generated_title(number, year)
    "Sprint #{number} Retrospective - #{year}"
  end

  def self.next_sprint_number_for(team)
    stored = team.retrospectives.maximum(:sprint_number).to_i
    derived = max_label_sprint_number_for(team)
    [stored, derived].max + 1
  end

  def self.generated_identity_for(team, at: Time.zone.now)
    number = next_sprint_number_for(team)
    year = calendar_year(at)
    {
      sprint_number: number,
      sprint_year: year,
      sprint_label: sprint_identifier(number, year),
      title: generated_title(number, year)
    }
  end

  def self.max_label_sprint_number_for(team)
    labels = team.retrospectives.where.not(sprint_label: [nil, ""]).pluck(:sprint_label)
    labels.filter_map { |label| label.to_s[SPRINT_LABEL_NUMBER, 1]&.to_i }.max || 0
  end
  private_class_method :max_label_sprint_number_for

  private

  def team_must_not_have_another_running_retrospective
    return if team.blank? || !running?
    return unless team.retrospectives.running.exists?

    errors.add(:base, ONE_ACTIVE_MESSAGE)
  end
end
