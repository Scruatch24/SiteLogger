class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :logs, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_one :profile, dependent: :destroy

  def self.from_omniauth(auth)
    # First check if a user already exists with this provider+uid
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Check if a user exists with the same email (e.g. signed up via email form)
    email_user = find_by(email: auth.info.email)
    if email_user
      # Link Google account to existing email user and confirm them
      email_user.update(provider: auth.provider, uid: auth.uid)
      email_user.confirm unless email_user.confirmed?
      return email_user
    end

    # Create a new user for first-time Google sign-in
    create do |user|
      user.email = auth.info.email
      user.provider = auth.provider
      user.uid = auth.uid
      user.password = Devise.friendly_token[0, 20]
      user.skip_confirmation! # Google users are already verified
    end
  end
  # If a user resets their password, they have proven they own the email.
  # We should confirm them automatically so they aren't stuck.
  def after_password_reset
    super
    confirm unless confirmed?
  end

  def send_devise_notification(notification, *args)
    # Use the system_language from the profile if available, otherwise default to current locale
    # This ensures emails are sent in the user's preferred language even if triggered from background jobs
    locale = profile&.system_language || I18n.locale
    I18n.with_locale(locale) do
      super
    end
  end
end
