class Teams::Archive
  class Error < StandardError; end

  ALREADY_ARCHIVED_MESSAGE = "This team is already archived.".freeze
  CANNOT_ARCHIVE_PREFIX = "Cannot archive this team.".freeze

  def self.combined_message(details)
    "#{CANNOT_ARCHIVE_PREFIX} #{details.join(' ')}"
  end

  def initialize(team)
    @team = team
  end

  def call
    raise Error, ALREADY_ARCHIVED_MESSAGE if @team.archived?

    Team.transaction do
      @team.lock!
      raise Error, ALREADY_ARCHIVED_MESSAGE if @team.reload.archived?

      messages = blocking_messages
      raise Error, self.class.combined_message(messages) if messages.any?

      cancel_draft_retrospective
      deactivate_memberships
      @team.update!(archived_at: Time.current)
    end
  end

  private

  def blocking_messages
    [active_retrospective_message, unresolved_action_items_message].compact
  end

  def active_retrospective_message
    retrospective = @team.retrospectives.in_session.order(:created_at).first
    return if retrospective.blank?

    label = retrospective.sprint_label.presence || retrospective.title
    "This team has an active retrospective, #{label}. " \
      "Close or cancel the retrospective before archiving the team."
  end

  def unresolved_action_items_message
    count = @team.action_items.unresolved.count
    return if count.zero?

    "This team has #{count} unresolved action items. " \
      "Complete, cancel, or reassign them before archiving the team."
  end

  def cancel_draft_retrospective
    draft = @team.retrospectives.draft.first
    return if draft.blank?

    Retrospectives::Cancel.new(draft).call
  end

  def deactivate_memberships
    now = Time.current
    @team.memberships.current.find_each do |membership|
      membership.update!(deactivated_at: now)
    end
  end
end
