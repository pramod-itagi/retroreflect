module SystemAdmin
  class TeamArchivesController < BaseController
    before_action :set_team

    def new
      authorize!(@team, :archive?)
    end

    def create
      authorize!(@team, :archive?)
      unless params[:confirmation_name].to_s == @team.name
        redirect_to new_system_admin_team_archive_path(@team), alert: "Type the team name exactly to confirm archiving."
        return
      end

      Teams::Archive.new(@team).call
      redirect_to system_admin_teams_path, notice: "Team archived."
    rescue Teams::Archive::Error => e
      redirect_to system_admin_team_path(@team), alert: e.message
    end

    private

    def set_team
      @team = Team.find(params[:id] || params[:team_id])
    end
  end
end
