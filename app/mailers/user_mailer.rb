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

  def activity_digest(user, stats)
    @user = user
    @stats = stats
    @locale = user.profile&.system_language || :en
    @currency_sym = currency_symbol_for(user.profile&.currency || "USD")

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.activity_digest.subject", month: stats[:month_name])
      )
    end
  end

  def payment_receipt(user, amount:, currency:, transaction_id:, plan_name: "Pro")
    @user = user
    @amount = amount
    @currency = currency
    @currency_sym = currency_symbol_for(currency)
    @transaction_id = transaction_id
    @plan_name = plan_name
    @locale = user.profile&.system_language || :en

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.payment_receipt.subject")
      )
    end
  end

  def payment_failed(user, amount:, currency:, next_attempt_at: nil)
    @user = user
    @amount = amount
    @currency = currency
    @currency_sym = currency_symbol_for(currency)
    @next_attempt_at = next_attempt_at
    @locale = user.profile&.system_language || :en

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.payment_failed.subject")
      )
    end
  end

  def renewal_reminder(user, amount:, currency:, renewal_date:)
    @user = user
    @amount = amount
    @currency = currency
    @currency_sym = currency_symbol_for(currency)
    @renewal_date = renewal_date
    @locale = user.profile&.system_language || :en

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.renewal_reminder.subject", date: renewal_date.strftime("%b %d"))
      )
    end
  end

  def subscription_canceled(user, ends_at: nil)
    @user = user
    @ends_at = ends_at
    @locale = user.profile&.system_language || :en

    I18n.with_locale(@locale) do
      mail(
        to: user.email,
        subject: I18n.t("user_mailer.subscription_canceled.subject")
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
