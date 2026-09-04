module TeamsHelper
  def teams_index_lede
    if current_user.system_admin?
      "Manage all teams and oversee retrospectives across the workspace."
    elsif current_user.facilitator?
      "Manage the teams you facilitate and keep their retrospectives moving."
    else
      "See the teams you're part of and follow their retrospectives."
    end
  end

  def teams_index_empty_copy
    if current_user.facilitator? || current_user.system_admin?
      "You don't have any teams assigned to you yet."
    else
      "You haven't been added to any teams yet."
    end
  end

  def workspace_team_path(team)
    policy = TeamPolicy.new(current_user, team)
    if policy.show?
      facilitator_team_path(team)
    elsif policy.administer?
      system_admin_team_path(team)
    else
      facilitator_teams_path
    end
  end
end
