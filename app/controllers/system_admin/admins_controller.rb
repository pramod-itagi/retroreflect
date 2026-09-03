module SystemAdmin
  class AdminsController < BaseController
    def index
      @system_admins = User.system_admins.order(:name)
      @candidate_users = User.active.where.not(confirmed_at: nil).where(system_admin: false).order(:name)
    end

    def create
      @operation_error_message = "We couldn't add that system admin. Please try again."
      if params[:user_id].blank?
        fail_operation("Select a confirmed user.", fallback: system_admin_admins_path)
        return
      end

      user = User.active.find(params[:user_id])
      unless user.confirmed?
        fail_operation("Select a confirmed user.", fallback: system_admin_admins_path)
        return
      end

      user.grant_system_admin!
      redirect_to system_admin_admins_path, notice: "#{user.display_name} is now a System Admin."
    end

    def destroy
      user = User.active.find(params[:id])
      @operation_error_message = "We couldn't remove #{user.display_name} as a system admin. Please try again."
      if user.revoke_system_admin
        redirect_to system_admin_admins_path, notice: "#{user.display_name} is no longer a System Admin."
      else
        fail_operation(
          user.errors.full_messages.to_sentence.presence || @operation_error_message,
          fallback: system_admin_admins_path
        )
      end
    end
  end
end
