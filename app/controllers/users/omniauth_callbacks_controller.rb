class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      # Generate a new session token — invalidates all other sessions for this user
      token = SecureRandom.hex(32)
      @user.update_column(:session_token, token)
      session[:session_token] = token
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "Google"
      sign_in_and_redirect @user, event: :authentication
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra") # Removing extra as it can overflow some session stores
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    flash[:alert] = t("devise.omniauth_callbacks.failure", kind: "OAuth", reason: params[:message].to_s.humanize) if params[:message].present?
    redirect_to root_path
  end
end
