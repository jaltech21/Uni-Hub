# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Skip CSRF verification for destroy action (logout)
  skip_before_action :verify_authenticity_token, only: :destroy

  # GET|DELETE /resource/sign_out
  def destroy
    super
  end
end
