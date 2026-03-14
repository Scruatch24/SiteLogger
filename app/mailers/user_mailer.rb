class UserMailer < ApplicationMailer
  layout "mailer"

  def welcome(user)
    @user = user
    @locale = user.profile&.system_language || :en
    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.welcome.subject")
      )
    end
  end

  def overdue_digest(user, overdue_logs)
    @user = user
    @overdue_logs = overdue_logs
    @locale = user.profile&.system_language || :en
    @currency_sym = currency_symbol_for(user.profile&.currency || "USD")

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.overdue_digest.subject", count: overdue_logs.size)
      )
    end
  end

  private

  def currency_symbol_for(code)
    {
      "USD" => "$", "EUR" => "€", "GBP" => "£", "GEL" => "₾",
      "RUB" => "₽", "TRY" => "₺", "JPY" => "¥", "CAD" => "CA$",
      "AUD" => "A$", "CHF" => "CHF", "INR" => "₹", "BRL" => "R$"
    }[code] || code
  end
end
