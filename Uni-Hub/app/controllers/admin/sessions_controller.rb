class Admin::SessionsController < Devise::SessionsController
  layout 'admin_auth'
  skip_before_action :authenticate_user!
  
  # GET /admin/login
  def new
    if user_signed_in? && current_user.admin?
      redirect_to admin_root_path
    elsif user_signed_in? && !current_user.admin?
      sign_out current_user
      flash[:alert] = "Admin access only. Please sign in with an admin account."
    end
    super
  end

  # POST /admin/login
  def create
    self.resource = warden.authenticate!(auth_options)
    
    unless resource.admin?
      sign_out resource
      flash[:alert] = "Access denied. This area is restricted to administrators only."
      redirect_to new_admin_session_path and return
    end
    
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  # DELETE /admin/logout
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    redirect_to new_admin_session_path
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    else
      sign_out resource
      new_admin_session_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    new_admin_session_path
  end
end
