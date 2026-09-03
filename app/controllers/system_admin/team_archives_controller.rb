module SystemAdmin
  class TeamArchivesController < BaseController
    before_action :set_team

    def new
      authorize!(@team, :archive?)
    end

    def create
      authorize!(@team, :archive?)
      @operation_error_message = "We couldn't archive this team. Please try again."
      unless params[:confirmation_name].to_s == @team.name
        fail_operation("Type the team name exactly to confirm archiving.", fallback: new_system_admin_team_archive_path(@team))
        return
      end

      Teams::Archive.new(@team).call
      redirect_to system_admin_teams_path, notice: "Team archived."
    rescue Teams::Archive::Error => e
      fail_operation(e.message, fallback: system_admin_team_path(@team))
    end

    private

    def set_team
      @team = Team.find(params[:id] || params[:team_id])
    end
  end
end
