class ActionItem < ApplicationRecord
  STATUSES = %w[open in_progress ready_for_review completed cancelled].freeze
  TERMINAL_STATUSES = %w[completed cancelled].freeze
  UNRESOLVED_STATUSES = %w[open in_progress ready_for_review].freeze
  STATUS_COMMENT_MAX = 2_000

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
  has_many :status_events, -> { order(:created_at, :id) },
           class_name: "ActionItemStatusEvent",
           inverse_of: :action_item,
           dependent: :destroy

  attr_accessor :status_comment

  scope :unresolved, -> { where(status: UNRESOLVED_STATUSES) }

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
  validate :due_on_cannot_be_in_the_past, on: :create

  before_save :stamp_terminal_status

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def available_statuses(for_owner: false)
    next_statuses = ALLOWED_TRANSITIONS.fetch(status, [])
    next_statuses -= %w[cancelled] if for_owner
    next_statuses
  end

  def selectable_statuses(for_owner: false)
    STATUSES.intersection([status, *available_statuses(for_owner: for_owner)])
  end

  def owner_may_transition_to?(new_status)
    selectable_statuses(for_owner: true).include?(new_status.to_s)
  end

  def apply_status_change(new_status, comment:, actor:)
    transaction do
      lock!
      requested = new_status.to_s
      return true if requested.blank? || requested == status

      note = comment.to_s.strip
      if note.blank?
        errors.add(:status_comment, "must explain what changed")
        return false
      end
      if note.length > STATUS_COMMENT_MAX
        errors.add(:status_comment, "is too long (maximum is #{STATUS_COMMENT_MAX} characters)")
        return false
      end

      from_status = status
      unless update(status: requested)
        return false
      end

      status_events.create!(
        previous_status: from_status,
        new_status: status,
        comment: note,
        actor: actor
      )
      true
    end
  rescue ActiveRecord::RecordInvalid
    reload if persisted?
    errors.add(:base, "We couldn't save that status update.")
    false
  end

  private

  def owner_must_belong_to_team
    return if owner.blank? || team.blank?

    unless team.current_memberships.exists?(user: owner)
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

  def due_on_cannot_be_in_the_past
    return if due_on.blank?
    return unless due_on < Time.zone.today

    errors.add(:due_on, "must be today or a future date")
  end
end
