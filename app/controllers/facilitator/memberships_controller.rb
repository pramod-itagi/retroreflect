module Facilitator
  class MembershipsController < BaseController
    def create
      team = Team.find(params[:team_id])
      authorize!(team, :manage_members?)
      @operation_error_message = "We couldn't add that person to the team. Please try again."
      if params[:user_id].blank?
        fail_operation("Select a person.", fallback: facilitator_team_path(team))
        return
      end

      user = User.active.find(params[:user_id])
      membership = team.memberships.new(user: user, role: params[:role])
      @operation_error_message = "We couldn't add #{user.display_name} to the team. Please try again."

      if membership.save
        redirect_to facilitator_team_path(team), notice: "#{user.display_name} added as #{membership.role}."
      else
        fail_operation(
          membership.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: facilitator_team_path(team)
        )
      end
    end

    def update
      team = Team.find(params[:team_id])
      authorize!(team, :manage_members?)
      membership = team.memberships.find(params[:id])
      @operation_error_message = "We couldn't update #{membership.user.display_name}. Please try again."

      if membership.update(role: params[:role])
        redirect_to facilitator_team_path(team), notice: "#{membership.user.display_name} is now a #{membership.role}."
      else
        fail_operation(
          membership.errors.full_messages.to_sentence.presence || "Unable to change role.",
          fallback: facilitator_team_path(team)
        )
      end
    end

    def confirm
      @team = Team.find(params[:team_id])
      authorize!(@team, :manage_members?)
      @membership = @team.memberships.find(params[:id])
    end

    def destroy
      team = Team.find(params[:team_id])
      authorize!(team, :manage_members?)
      membership = team.memberships.find(params[:id])
      @operation_error_message = "We couldn't remove #{membership.user.display_name} from the team. Please try again."

      if membership.last_current_facilitator?
        fail_operation("This team must have at least one Facilitator.", fallback: facilitator_team_path(team))
        return
      end

      if membership.user_id == current_user.id && membership.facilitator?
        fail_operation("You cannot remove yourself as a facilitator.", fallback: facilitator_team_path(team))
        return
      end

      if membership.destroy
        redirect_to facilitator_team_path(team), notice: "Member removed."
      else
        fail_operation(
          membership.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: facilitator_team_path(team)
        )
      end
    end
  end
end
