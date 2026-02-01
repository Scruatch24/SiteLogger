class Users::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource(sign_up_params)

    # Check if a user with this email already exists
    existing_user = User.find_by(email: resource.email)

    if existing_user && !existing_user.confirmed?
      # SILENT RE-SEND: Update password (in case of typo) and resend the link
      existing_user.update(password: sign_up_params[:password], password_confirmation: sign_up_params[:password_confirmation])
      existing_user.send_confirmation_instructions
      set_flash_message! :notice, :send_instructions
      respond_with resource, location: after_inactive_sign_up_path_for(resource)
    else
      # Normal behavior for new users or already confirmed users
      super
    end
  end
end
