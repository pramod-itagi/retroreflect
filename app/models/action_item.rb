class ActionItem < ApplicationRecord
  STATUSES = %w[open in_progress ready_for_review completed cancelled].freeze
  TERMINAL_STATUSES = %w[completed cancelled].freeze

  ALLOWED_TRANSITIONS = {
    "open" => %w[in_progress ready_for_review completed cancelled],
    "in_progress" => %w[open ready_for_review completed cancelled],
    "ready_for_review" => %w[in_progress completed cancelled],
    "completed" => [],
    "cancelled" => []
  }.freeze

  belongs_to :team
  belongs_to :retrospective, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :owner, class_name: "User"
  belongs_to :completed_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true

  enum :status, {
    open: "open",
    in_progress: "in_progress",
    ready_for_review: "ready_for_review",
    completed: "completed",
    cancelled: "cancelled"
  }, validate: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :due_on, presence: true
  validate :owner_must_belong_to_team
  validate :status_transition_allowed, if: :status_changed?

  before_save :stamp_terminal_status

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def available_statuses(for_owner: false)
    next_statuses = ALLOWED_TRANSITIONS.fetch(status, [])
    next_statuses -= %w[cancelled] if for_owner
    next_statuses
  end

  def owner_may_transition_to?(new_status)
    available_statuses(for_owner: true).include?(new_status)
  end

  private

  def owner_must_belong_to_team
    return if owner.blank? || team.blank?

    unless team.memberships.exists?(user: owner)
      errors.add(:owner, "must belong to the team")
      return
    end

    errors.add(:owner, "must be an active account") if owner.discarded?
  end

  def status_transition_allowed
    return if new_record?
    return if ALLOWED_TRANSITIONS.fetch(status_was, []).include?(status)

    errors.add(:status, "cannot change from #{status_was} to #{status}")
  end

  def stamp_terminal_status
    if completed? && completed_at.blank?
      self.completed_at = Time.current
      self.completed_by ||= Current.user
    elsif cancelled? && cancelled_at.blank?
      self.cancelled_at = Time.current
      self.cancelled_by ||= Current.user
    end
  end
end
