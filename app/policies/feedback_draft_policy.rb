class FeedbackDraftPolicy < ApplicationPolicy
  def create?
    owner? && record.retrospective.collecting? && !record.participation.submitted?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  def owner?
    user.present? && record.participation.user_id == user.id
  end
end
