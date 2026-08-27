module SystemAdmin
  class AdminsController < BaseController
    def index
      @system_admins = User.system_admins.order(:name)
      @candidate_users = User.active.where.not(confirmed_at: nil).where(system_admin: false).order(:name)
    end

    def create
      if params[:user_id].blank?
        redirect_to system_admin_admins_path, alert: "Select a confirmed user."
        return
      end

      user = User.active.find(params[:user_id])
      unless user.confirmed?
        redirect_to system_admin_admins_path, alert: "Select a confirmed user."
        return
      end

      user.grant_system_admin!
      redirect_to system_admin_admins_path, notice: "#{user.display_name} is now a System Admin."
    end

    def destroy
      user = User.active.find(params[:id])
      if user.revoke_system_admin
        redirect_to system_admin_admins_path, notice: "#{user.display_name} is no longer a System Admin."
      else
        redirect_to system_admin_admins_path, alert: user.errors.full_messages.to_sentence
      end
    end
  end
end
