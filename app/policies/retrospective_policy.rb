class RetrospectivePolicy < ApplicationPolicy
  def show?
    facilitator? || participating?
  end

  def create?
    facilitator_of?(record.team)
  end

  def update?
    facilitator? && record.draft?
  end

  def manage_roster?
    facilitator? && record.draft?
  end

  def start_collecting?
    facilitator? && record.draft?
  end

  def reveal?
    facilitator? && record.collecting?
  end

  def close?
    facilitator? && record.discussing?
  end

  def cancel?
    facilitator? && (record.draft? || record.collecting?)
  end

  def view_roster?
    facilitator?
  end

  def view_meeting?
    facilitator? && record.revealed?
  end

  def write_drafts?
    participating? && record.collecting? && !own_participation&.submitted?
  end

  def view_own_drafts?
    participating? && record.collecting?
  end

  def submit_notes?
    write_drafts?
  end

  def participate?
    participating?
  end

  private

  def facilitator?
    facilitator_of?(record.team)
  end

  def participating?
    own_participation.present?
  end

  def own_participation
    return if user.blank?

    record.participations.find_by(user: user)
  end
end
