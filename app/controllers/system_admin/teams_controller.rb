module SystemAdmin
  class TeamsController < BaseController
    def index
      @active_teams = Team.active.includes(:current_memberships).order(:name)
      @archived_teams = Team.archived.order(:name)
    end

    def show
      @team = Team.find(params[:id])
      authorize!(@team, :administer?)
      @memberships = @team.current_memberships.includes(:user).order(:role, :id)
    end

    def new
      @team = Team.new
      authorize!(@team, :create?)
      load_facilitator_choices
    end

    def create
      @team = Team.new(name: team_params[:name], created_by: current_user)
      authorize!(@team, :create?)

      facilitator = find_initial_facilitator
      @team = Teams::Create.new(created_by: current_user, name: team_params[:name], facilitator: facilitator).call

      if @team.errors.empty?
        redirect_to system_admin_team_path(@team), notice: "Team created."
      else
        load_facilitator_choices
        render :new, status: :unprocessable_content
      end
    end

    private

    def team_params
      params.require(:team).permit(:name)
    end

    def find_initial_facilitator
      return if params[:facilitator_id].blank?

      User.active.find_by(id: params[:facilitator_id])
    end

    def load_facilitator_choices
      @candidate_users = User.active.where.not(confirmed_at: nil).order(:name)
    end
  end
end
