class Users::SessionsController < Devise::SessionsController
  def create
    super do |user|
      # Generate a new session token — invalidates all other sessions for this user
      token = SecureRandom.hex(32)
      user.update_column(:session_token, token)
      session[:session_token] = token
    end
  end
end
