module SystemAdmin
  class BaseController < ApplicationController
    before_action :require_confirmed_email
    before_action :require_system_admin
  end
end
