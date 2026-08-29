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

  def nav_link(name, path)
    active = current_page?(path)
    html_options = { class: active ? "font-semibold text-[#10211d]" : "text-slate-600 hover:text-slate-900" }
    html_options[:aria] = { current: "page" } if active
    link_to name, path, html_options
  end

  def action_item_overdue?(item)
    item.due_on < Date.current && !item.terminal?
  end

  def action_item_badge_classes(status)
    base = "inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold"
    case status.to_s
    when "in_progress"
      "#{base} bg-moss text-white"
    when "ready_for_review"
      "#{base} bg-ink text-white"
    when "completed"
      "#{base} bg-[#dce9df] text-moss"
    when "cancelled"
      "#{base} bg-sand text-[#5C574E]"
    else
      "#{base} bg-sand text-ink"
    end
  end
end
