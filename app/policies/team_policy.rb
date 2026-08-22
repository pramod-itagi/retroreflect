class TeamPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    facilitator_of?(record) || user.member_of?(record)
  end

  def create?
    user&.confirmed? && user.facilitator?
  end

  def update?
    facilitator_of?(record) && record.active?
  end

  def manage_members?
    facilitator_of?(record) && record.active?
  end

  def archive?
    facilitator_of?(record) && record.active?
  end
end
