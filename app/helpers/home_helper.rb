module HomeHelper
  def home_running_work
    @teams.filter_map do |team|
      retrospective = team.running_retrospective
      next if retrospective.blank?

      {
        team: team,
        retrospective: retrospective,
        facilitated: home_facilitator_of?(team)
      }
    end
  end

  def home_idle_facilitated_teams
    @teams.select { |team| home_facilitator_of?(team) && team.running_retrospective.blank? }
  end

  def home_facilitator_of?(team)
    @facilitated_team_ids.include?(team.id)
  end

  def home_primary_button_classes
    "home-action home-action-primary"
  end

  def home_quiet_link_classes
    "home-quiet-link"
  end

  def home_team_nav_link(team)
    arrow = %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none" aria-hidden="true" class="home-team-link-icon"><path d="M6 3.2 11.3 8 6 12.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>).html_safe

    link_to facilitator_team_path(team), class: "home-team-link" do
      safe_join([tag.span(team.name, class: "home-team-link-name"), arrow])
    end
  end

  def home_status_badge_classes(status)
    base = "inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold"
    case status.to_s
    when "collecting"
      "#{base} bg-coral text-white"
    when "discussing"
      "#{base} bg-ink text-white"
    else
      "#{base} bg-sand text-ink"
    end
  end
end
