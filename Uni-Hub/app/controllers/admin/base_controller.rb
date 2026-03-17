class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    unless user_signed_in? && (current_user.admin? || current_user.super_admin?)
      redirect_to new_admin_session_path, alert: "Please sign in with an admin account."
    end
  end
end
