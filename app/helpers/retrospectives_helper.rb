module RetrospectivesHelper
  def retrospective_listing_filters_applied?
    params[:team_id].present? || params[:status].present? || params[:q].to_s.strip.present?
  end

  def retrospective_status_badge_classes(status)
    base = "inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold"
    case status.to_s
    when "collecting"
      "#{base} bg-coral text-white"
    when "discussing"
      "#{base} bg-ink text-white"
    when "closed"
      "#{base} bg-[#dce9df] text-moss"
    when "cancelled"
      "#{base} bg-sand text-[#5C574E]"
    else
      "#{base} bg-sand text-ink"
    end
  end

  def retrospective_listing_cta_classes(variant)
    variant.to_s == "previous" ? "home-action home-action-secondary shrink-0" : "#{home_primary_button_classes} shrink-0"
  end

  def participation_status_badge_classes(label)
    base = "inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold"
    case label
    when "Submitted", "Opened"
      "#{base} bg-[#dce9df] text-moss"
    when "Invited"
      "#{base} bg-ink text-white"
    else
      "#{base} bg-sand text-ink"
    end
  end
end
