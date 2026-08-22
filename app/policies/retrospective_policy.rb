class RetrospectivePolicy < ApplicationPolicy
  def show?
    facilitator? || participating?
  end

  def create?
    facilitator_of?(record.team) && record.team.active?
  end

  def update?
    facilitator? && record.draft? && record.team.active?
  end

  def manage_roster?
    facilitator? && record.draft? && record.team.active?
  end

  def start_collecting?
    facilitator? && record.draft? && record.team.active?
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

  def index?
    user&.confirmed?
  end

  def view_roster?
    facilitator? || historically_facilitated?
  end

  def view_meeting?
    (facilitator? || historically_facilitated?) && record.revealed?
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

  def historically_facilitated?
    user.present? && user.historically_facilitated?(record.team)
  end

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
