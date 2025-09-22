class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(resource)
    words_path  # Redirect to words index after sign-in
  end

  def after_sign_out_path_for(resource_or_scope)
    logout_path  # Redirect to your custom logout page
  end
end
