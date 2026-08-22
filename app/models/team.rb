class Team < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :memberships, dependent: :restrict_with_exception
  has_many :current_memberships, -> { current }, class_name: "Membership", inverse_of: :team, dependent: false
  has_many :users, through: :current_memberships
  has_many :retrospectives, dependent: :restrict_with_exception
  has_many :action_items, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 100 }

  scope :active, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def active?
    !archived?
  end

  def name_for_select
    archived? ? "#{name} (archived)" : name
  end

  def members
    users.merge(Membership.member)
  end

  def facilitators
    users.merge(Membership.facilitator)
  end

  def running_retrospective
    candidates = if retrospectives.loaded?
                   retrospectives.select(&:running?)
                 else
                   retrospectives.running.to_a
                 end
    candidates.min_by(&:created_at)
  end

  def member_count
    if current_memberships.loaded?
      current_memberships.size
    else
      current_memberships.count
    end
  end
end
