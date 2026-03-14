class ActivityDigestJob < ApplicationJob
  queue_as :default

  def perform
    last_month = Date.current.last_month
    month_name = last_month.strftime("%B %Y")
    start_date = last_month.beginning_of_month
    end_date   = last_month.end_of_month

    User.joins(:profile).where(profiles: { plan: "paid" }).find_each do |user|
      logs = user.logs.kept.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

      stats = {
        month_name:       month_name,
        invoices_created: logs.count,
        total_billed:     logs.sum { |l| l.cached_total_due.to_f },
        paid_count:       logs.where(status: "paid").count,
        overdue_count:    logs.where(status: "overdue").count
      }

      UserMailer.activity_digest(user, stats).deliver_later
    rescue => e
      Rails.logger.error("ActivityDigestJob failed for user #{user.id}: #{e.message}")
    end
  end
end
