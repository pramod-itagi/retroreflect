module ApplicationHelper
  def back_link(path, destination)
    link_to "Back to #{destination}", path, class: "underline"
  end

  def can_create_team?
    TeamPolicy.new(current_user, Team.new).create?
  end

  def display_name_for(user)
    user&.display_name || "Unknown User"
  end

  def flash_class(type)
    case type.to_s
    when "notice" then "bg-teal-50 text-teal-900 border-teal-200"
    else "bg-red-50 text-red-900 border-red-200"
    end
  end

  def category_label(category)
    Retrospective::CATEGORIES.fetch(category.to_s, category.to_s.humanize)
  end

  def action_status_label(status)
    status.to_s.humanize
  end

  def submission_progress(retrospective)
    "#{retrospective.submitted_count} / #{retrospective.participant_count} submitted"
  end

  def retrospective_cta(retrospective, facilitated:)
    label, path = retrospective_cta_parts(retrospective, facilitated: facilitated)
    return if path.blank?

    link_to label, path, class: "text-sm text-teal-800 underline"
  end

  def retrospective_cta_parts(retrospective, facilitated:)
    if facilitated
      facilitated_cta_parts(retrospective)
    elsif collecting_participant?(retrospective)
      ["Continue", participant_retrospective_path(retrospective)]
    end
  end

  def facilitated_cta_parts(retrospective)
    if retrospective.draft?
      ["Continue Setup", facilitator_retrospective_path(retrospective)]
    elsif retrospective.collecting?
      ["Continue", facilitator_retrospective_path(retrospective)]
    elsif retrospective.revealed?
      [retrospective.closed? ? "View" : "Continue", facilitator_retrospective_meeting_path(retrospective)]
    else
      ["View", facilitator_retrospective_path(retrospective)]
    end
  end

  def collecting_participant?(retrospective)
    retrospective.collecting? && retrospective.participations.any? { |participation| participation.user_id == current_user.id }
  end
end
