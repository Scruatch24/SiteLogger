class DeviseCustomMailer < Devise::Mailer
  helper :application # gives access to all helpers defined within `application_helper`.
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
  default from: "TalkInvoice <contact@talkinvoice.online>"
  layout "mailer"

  def confirmation_instructions(record, token, opts = {})
    opts[:subject] = I18n.t("devise.mailer.confirmation_instructions.subject", ref: SecureRandom.hex(3).upcase)
    super
  end

  def reset_password_instructions(record, token, opts = {})
    opts[:subject] = I18n.t("devise.mailer.reset_password_instructions.subject", ref: SecureRandom.hex(3).upcase)
    super
  end

  def unlock_instructions(record, token, opts = {})
    opts[:subject] = I18n.t("devise.mailer.unlock_instructions.subject", ref: SecureRandom.hex(3).upcase)
    super
  end
end
