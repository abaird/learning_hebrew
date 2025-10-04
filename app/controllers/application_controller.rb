class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  protected

  def after_sign_in_path_for(resource)
    root_path  # Redirect to dictionary (root) after sign-in
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path  # Redirect to root (which will redirect to sign in)
  end
end
