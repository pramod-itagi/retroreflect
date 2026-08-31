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

  def app_alert_kind(type)
    case type.to_s
    when "notice", "success" then "success"
    when "warning" then "warning"
    else "error"
    end
  end

  def app_alert(kind:, message: nil, messages: nil, autohide: true)
    render partial: "shared/app_alert", locals: { kind: kind.to_s, message: message, messages: messages, autohide: autohide }
  end

  def render_app_alerts
    safe_join(
      flash.filter_map do |type, message|
        next if message.blank?

        app_alert(kind: app_alert_kind(type), message: message)
      end
    )
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
    active = nav_link_active?(path)
    html_options = { class: ["app-nav-link", ("is-active" if active)].compact.join(" ") }
    html_options[:aria] = { current: "page" } if active
    link_to name, path, html_options
  end

  def nav_link_active?(path)
    return current_page?(root_path) if path == root_path

    current_page?(path) || request.path.start_with?("#{path}/")
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
