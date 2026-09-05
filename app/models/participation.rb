class Participation < ApplicationRecord
  INVITATION_TTL = 14.days

  belongs_to :retrospective
  belongs_to :user
  has_many :feedback_drafts, dependent: :destroy

  validates :user_id, uniqueness: { scope: :retrospective_id }
  validate :user_must_be_team_member, on: :create
  validate :roster_must_be_editable, on: :create

  scope :submitted, -> { where.not(submitted_at: nil) }

  def submitted?
    submitted_at.present?
  end

  def invitation_accepted?
    accessed_at.present?
  end

  def invitation_expired?
    invited_at.present? && invited_at < INVITATION_TTL.ago
  end

  def accept_invitation!
    update!(accessed_at: Time.current) if accessed_at.blank?
  end

  def invitation_status_label
    if accessed_at.present?
      "Opened"
    elsif invited_at.present?
      "Invited"
    else
      "Not invited"
    end
  end

  def response_status_label
    submitted? ? "Submitted" : "Not submitted"
  end

  def submit_responses
    submitted = false

    Retrospective.transaction do
      locked = Retrospective.lock.find(retrospective_id)
      self.retrospective = locked
      reload

      if submitted?
        errors.add(:base, "already submitted")
        raise ActiveRecord::Rollback
      end
      unless locked.collecting?
        errors.add(:base, "this retrospective is no longer collecting")
        raise ActiveRecord::Rollback
      end
      if feedback_drafts.none?
        errors.add(:base, "add at least one note before submitting")
        raise ActiveRecord::Rollback
      end

      submitted = update(submitted_at: Time.current)
      raise ActiveRecord::Rollback unless submitted
    end

    submitted
  end

  private

  def user_must_be_team_member
    return if user.blank? || retrospective.blank?
    return if user.member_of?(retrospective.team)

    errors.add(:user, "must be a member of the team")
  end

  def roster_must_be_editable
    return if retrospective.blank? || retrospective.draft?

    errors.add(:base, "roster is frozen")
  end
end
