module ApplicationHelper
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
end
