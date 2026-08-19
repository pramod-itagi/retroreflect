class ActionItemPolicy < ApplicationPolicy
  def create?
    facilitator_of?(record.team)
  end

  def update?
    facilitator_of?(record.team)
  end

  def update_as_owner?
    user.present? && record.owner_id == user.id && !record.terminal?
  end
end
