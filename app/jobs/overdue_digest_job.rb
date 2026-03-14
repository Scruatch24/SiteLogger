class OverdueDigestJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.today

    User.joins(:profile).where(profiles: { paid: true }).find_each do |user|
      profile = user.profile
      next unless profile

      overdue_logs = []
      user.logs.kept.where(status: "overdue").find_each do |log|
        parsed_due = log.parsed_due_date
        next unless parsed_due && parsed_due < today

        days_overdue = (today - parsed_due).to_i
        amount = log.cached_total_due.to_f.round(2)

        overdue_logs << {
          id: log.id,
          display_number: log.display_number,
          client: log.client.to_s.strip,
          amount: amount,
          due_date: parsed_due,
          days_overdue: days_overdue
        }
      end

      next if overdue_logs.empty?

      overdue_logs.sort_by! { |l| -l[:days_overdue] }

      UserMailer.overdue_digest(user, overdue_logs).deliver_later
      Rails.logger.info "[OverdueDigestJob] Sent digest to #{user.email} (#{overdue_logs.size} overdue)"
    rescue => e
      Rails.logger.error "[OverdueDigestJob] Failed for user #{user.id}: #{e.message}"
    end
  end
end
