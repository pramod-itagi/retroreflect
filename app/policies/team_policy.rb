class TeamPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    facilitator_of?(record) || user.member_of?(record)
  end

  def create?
    user&.confirmed? && system_admin?
  end

  def update?
    facilitator_of?(record) && record.active?
  end

  def manage_members?
    facilitator_of?(record) && record.active?
  end

  def administer?
    system_admin?
  end

  def archive?
    (facilitator_of?(record) || system_admin?) && record.active?
  end
end
