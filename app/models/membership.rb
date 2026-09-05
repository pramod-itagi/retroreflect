class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { facilitator: "facilitator", member: "member" }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }
  validate :user_must_be_active_and_confirmed, on: :create
  validate :team_must_be_active_for_new_current_membership, on: :create
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

  def update(attributes)
    if facilitator_demotion?(attributes)
      with_locked_team_facilitators { super }
    else
      super
    end
  end

  def destroy
    if current_facilitator_membership?
      with_locked_team_facilitators { super }
    else
      super
    end
  end

  private

  def user_must_be_active_and_confirmed
    return if user&.confirmed? && !user.discarded?

    errors.add(:user, "must be an active confirmed account")
  end

  def team_must_be_active_for_new_current_membership
    return unless current?
    return if team_id.blank?

    locked_team = Team.lock.find(team_id)
    return unless locked_team.archived?

    errors.add(:base, "This team is archived.")
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

  def facilitator_demotion?(attributes)
    return false if attributes.blank?

    requested_role = (attributes[:role] || attributes["role"]).to_s
    requested_role == "member" && current_facilitator_membership?
  end

  def current_facilitator_membership?
    current? && persisted? && (facilitator? || role_in_database == "facilitator")
  end

  def with_locked_team_facilitators
    result = false

    self.class.transaction do
      Team.lock.find(team_id)
      self.class.current.facilitator.where(team_id: team_id).lock.order(:id).to_a
      reload
      result = yield
      raise ActiveRecord::Rollback unless result
    end

    result
  rescue ActiveRecord::RecordNotFound
    false
  end
end
