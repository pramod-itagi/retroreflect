class User < ApplicationRecord
  CONFIRMATION_TOKEN_TTL = 24.hours
  PASSWORD_RESET_TOKEN_TTL = 2.hours

  has_secure_password

  has_many :memberships, dependent: :restrict_with_exception
  has_many :current_memberships, -> { current }, class_name: "Membership", inverse_of: :user, dependent: false
  has_many :teams, through: :current_memberships
  has_many :created_teams, class_name: "Team", foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_exception
  has_many :participations, dependent: :restrict_with_exception
  has_many :owned_action_items, class_name: "ActionItem", foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_exception

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :active, -> { where(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  def confirmed?
    confirmed_at.present?
  end

  def display_name
    discarded? ? "Unknown User" : name
  end

  def facilitator?
    current_memberships.facilitator.exists?
  end

  def facilitator_of?(team)
    current_memberships.exists?(team: team, role: :facilitator)
  end

  def historically_facilitated?(team)
    memberships.exists?(team: team, role: :facilitator)
  end

  def member_of?(team)
    current_memberships.exists?(team: team, role: :member)
  end

  def facilitated_teams
    Team.where(archived_at: nil)
        .joins(:current_memberships)
        .where(memberships: { user_id: id, role: :facilitator })
        .distinct
  end

  def member_teams
    Team.where(archived_at: nil)
        .joins(:current_memberships)
        .where(memberships: { user_id: id, role: :member })
        .distinct
  end

  def accessible_retrospectives
    Retrospective.where(team_id: memberships.facilitator.select(:team_id))
                 .or(Retrospective.where(id: participations.select(:retrospective_id)))
  end

  def issue_confirmation_token!
    raw, digest = Token.generate
    update!(confirmation_token_digest: digest, confirmation_sent_at: Time.current)
    raw
  end

  def confirm!
    update!(confirmed_at: Time.current, confirmation_token_digest: nil, confirmation_sent_at: nil)
  end

  def confirmation_token_expired?
    confirmation_sent_at.blank? || confirmation_sent_at < CONFIRMATION_TOKEN_TTL.ago
  end

  def password_reset_token_expired?
    password_reset_sent_at.blank? || password_reset_sent_at < PASSWORD_RESET_TOKEN_TTL.ago
  end

  def self.find_for_email_confirmation(raw)
    user = find_active_by_token_digest(:confirmation_token_digest, raw)
    user if user && !user.confirmation_token_expired?
  end

  def self.find_for_password_reset(raw)
    user = find_active_by_token_digest(:password_reset_token_digest, raw)
    user if user && !user.password_reset_token_expired?
  end

  def self.find_active_by_token_digest(column, raw)
    return if raw.blank?

    active.find_by(column => Token.digest(raw))
  end
  private_class_method :find_active_by_token_digest

  def issue_password_reset_token!
    raw, digest = Token.generate
    update!(password_reset_token_digest: digest, password_reset_sent_at: Time.current)
    raw
  end

  def clear_password_reset_token!
    update!(password_reset_token_digest: nil, password_reset_sent_at: nil)
  end

  def discard!
    random_password = SecureRandom.hex(20)
    update!(
      discarded_at: Time.current,
      name: "Unknown User",
      email: "deleted+#{id}@tombstone.invalid",
      password: random_password,
      password_confirmation: random_password,
      confirmation_token_digest: nil,
      password_reset_token_digest: nil
    )
  end
end
