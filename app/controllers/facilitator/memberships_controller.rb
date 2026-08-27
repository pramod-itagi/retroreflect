module Facilitator
  class MembershipsController < BaseController
    def create
      team = Team.find(params[:team_id])
      authorize!(team, :manage_members?)
      if params[:user_id].blank?
        redirect_to facilitator_team_path(team), alert: "Select a person."
        return
      end

      user = User.active.find(params[:user_id])
      membership = team.memberships.new(user: user, role: params[:role])

      if membership.save
        redirect_to facilitator_team_path(team), notice: "#{user.display_name} added as #{membership.role}."
      else
        redirect_to facilitator_team_path(team), alert: membership.errors.full_messages.to_sentence
      end
    end

    def update
      team = Team.find(params[:team_id])
      authorize!(team, :manage_members?)
      membership = team.memberships.find(params[:id])

      if membership.update(role: params[:role])
        redirect_to facilitator_team_path(team), notice: "#{membership.user.display_name} is now a #{membership.role}."
      else
        redirect_to facilitator_team_path(team), alert: membership.errors.full_messages.to_sentence.presence || "Unable to change role."
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

      if membership.last_current_facilitator?
        redirect_to facilitator_team_path(team), alert: "This team must have at least one Facilitator."
        return
      end

      if membership.user_id == current_user.id && membership.facilitator?
        redirect_to facilitator_team_path(team), alert: "You cannot remove yourself as a facilitator."
        return
      end

      if membership.destroy
        redirect_to facilitator_team_path(team), notice: "Member removed."
      else
        redirect_to facilitator_team_path(team), alert: membership.errors.full_messages.to_sentence
      end
    end
  end
end
