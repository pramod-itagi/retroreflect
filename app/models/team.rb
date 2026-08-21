class Team < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :memberships, dependent: :restrict_with_exception
  has_many :users, through: :memberships
  has_many :retrospectives, dependent: :restrict_with_exception
  has_many :action_items, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 100 }

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
    memberships.loaded? ? memberships.size : memberships.count
  end
end
