module Facilitator
  class BaseController < ApplicationController
    before_action :require_confirmed_email
  end
end
