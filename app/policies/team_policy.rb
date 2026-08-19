class TeamPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    facilitator_of?(record) || user.member_of?(record)
  end

  def create?
    user&.confirmed?
  end

  def update?
    facilitator_of?(record)
  end

  def manage_members?
    facilitator_of?(record)
  end
end
