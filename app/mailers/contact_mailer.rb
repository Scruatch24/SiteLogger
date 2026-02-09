class ContactMailer < ApplicationMailer
  def notify_admin(email:, subject:, description:)
    @email = email
    @subject = subject
    @description = description
    mail(
      to: "contact@talkinvoice.online",
      subject: "Contact Form: #{subject}",
      reply_to: email
    )
  end

  def confirm_user(email:, locale: :en)
    @locale = locale
    mail(
      to: email,
      subject: I18n.t("contact_page.confirmation_subject", locale: locale)
    )
  end
end
