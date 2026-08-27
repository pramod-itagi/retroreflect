class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { facilitator: "facilitator", member: "member" }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }
  validate :user_must_be_active_and_confirmed, on: :create
  validate :team_must_keep_a_facilitator

  scope :current, -> { where(deactivated_at: nil) }

  before_destroy :prevent_removing_last_facilitator

  def current?
    deactivated_at.nil?
  end

  def last_current_facilitator?
    current? && persisted? && team&.active? &&
      (facilitator? || role_in_database == "facilitator") &&
      team.current_memberships.facilitator.where.not(id: id).none?
  end

  private

  def user_must_be_active_and_confirmed
    return if user&.confirmed? && !user.discarded?

    errors.add(:user, "must be an active confirmed account")
  end

  def team_must_keep_a_facilitator
    return unless will_save_change_to_role?
    return unless role_in_database == "facilitator" && member?
    return unless last_current_facilitator?

    errors.add(:base, "This team must have at least one Facilitator.")
  end

  def prevent_removing_last_facilitator
    return unless last_current_facilitator?

    errors.add(:base, "This team must have at least one Facilitator.")
    throw :abort
  end
end
