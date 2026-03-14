class RenewalReminderJob < ApplicationJob
  queue_as :default

  def perform
    target_date = 3.days.from_now.to_date

    Profile.where(plan: "paid", paddle_subscription_status: "active")
           .where.not(paddle_next_bill_at: nil)
           .find_each do |profile|
      next unless profile.user.present?

      bill_date = begin
        profile.paddle_next_bill_at.is_a?(String) ? Date.parse(profile.paddle_next_bill_at) : profile.paddle_next_bill_at.to_date
      rescue
        nil
      end

      next unless bill_date == target_date

      amount   = 9.99
      currency = profile.currency.presence || "USD"

      UserMailer.renewal_reminder(
        profile.user,
        amount:       amount,
        currency:     currency,
        renewal_date: bill_date
      ).deliver_later
    rescue => e
      Rails.logger.error("RenewalReminderJob failed for profile #{profile.id}: #{e.message}")
    end
  end
end
