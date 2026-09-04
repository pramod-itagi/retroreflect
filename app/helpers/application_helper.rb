module ApplicationHelper
  def back_nav_link(path, destination, extra_classes: nil)
    arrow = %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none" aria-hidden="true" class="home-back-link-icon"><path d="M10 3.2 4.7 8 10 12.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>).html_safe

    link_to path, class: ["home-back-link", extra_classes].compact.join(" ") do
      safe_join([arrow, tag.span("Back to #{destination}")], "")
    end
  end

  def back_link(path, destination)
    back_nav_link(path, destination)
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

  def app_alert(kind:, message: nil, messages: nil, title: nil, autohide: true)
    render partial: "shared/app_alert", locals: {
      kind: kind.to_s,
      title: title,
      message: message,
      messages: messages,
      autohide: autohide
    }
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

    link_to label, path, class: "home-quiet-link"
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
      ["Continue setup", facilitator_retrospective_path(retrospective)]
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

  def nav_link(name, path, html_options = {}, &block)
    active = nav_link_active?(path)
    css_class = ["app-nav-link", ("is-active" if active), html_options[:class]].compact.join(" ")
    html_options = html_options.merge(class: css_class)
    aria = (html_options[:aria] || {}).dup
    aria[:current] = "page" if active
    html_options[:aria] = aria if aria.present?

    if block
      link_to(path, html_options, &block)
    else
      link_to(name, path, html_options)
    end
  end

  def nav_link_active?(path)
    return current_page?(root_path) if path == root_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end

  def action_item_overdue?(item)
    item.due_on < Date.current && !item.terminal?
  end

  def action_item_calendar_date(value)
    date = value.to_date
    date.strftime("%b #{date.day}, %Y")
  end

  def action_item_due_label(item)
    "Due #{action_item_calendar_date(item.due_on)}"
  end

  def action_item_overdue_badge_classes
    "inline-flex rounded-full bg-coral px-2.5 py-0.5 text-xs font-semibold text-white"
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
