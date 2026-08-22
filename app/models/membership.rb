class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { facilitator: "facilitator", member: "member" }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }
  validate :user_must_be_active_and_confirmed, on: :create

  scope :current, -> { where(deactivated_at: nil) }

  def current?
    deactivated_at.nil?
  end

  private

  def user_must_be_active_and_confirmed
    return if user&.confirmed? && !user.discarded?

    errors.add(:user, "must be an active confirmed account")
  end
end
