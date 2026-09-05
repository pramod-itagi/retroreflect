class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  private

  def facilitator_of?(team)
    user.present? && team.present? && user.facilitator_of?(team)
  end

  def historically_facilitated?(team)
    user.present? && team.present? && user.historically_facilitated?(team)
  end

  def historically_associated_with?(team)
    user.present? && team.present? && user.associated_with?(team)
  end

  def system_admin?
    user.present? && user.system_admin?
  end
end
