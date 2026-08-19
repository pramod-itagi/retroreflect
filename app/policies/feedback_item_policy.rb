# Meeting access only. This policy must not expose an author.
class FeedbackItemPolicy < ApplicationPolicy
  def index?
    facilitator_of?(record.team) && record.revealed?
  end
end
