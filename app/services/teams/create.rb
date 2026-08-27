class Teams::Create
  def initialize(created_by:, name:, facilitator:)
    @created_by = created_by
    @name = name
    @facilitator = facilitator
    @team = Team.new(name: @name, created_by: @created_by)
  end

  def call
    unless valid_facilitator?
      @team.errors.add(:base, "Select a confirmed user.")
      return @team
    end

    Team.transaction do
      @team.save!
      @team.memberships.create!(user: @facilitator, role: :facilitator)
    end

    @team
  rescue ActiveRecord::RecordInvalid => e
    if e.record != @team
      e.record.errors.full_messages.each { |message| @team.errors.add(:base, message) }
    end
    @team
  end

  private

  def valid_facilitator?
    @facilitator.present? && @facilitator.confirmed? && !@facilitator.discarded?
  end
end
