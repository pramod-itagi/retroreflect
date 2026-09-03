class ActionItemPolicy < ApplicationPolicy
  def create?
    facilitator_of?(record.team) && record.team.active? && retrospective_allows_create?
  end

  def update?
    facilitator_of?(record.team) && record.team.active?
  end

  def update_as_owner?
    user.present? && record.owner_id == user.id && !record.terminal?
  end

  private

  def retrospective_allows_create?
    record.retrospective.blank? || record.retrospective.running?
  end
end
