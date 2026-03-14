namespace :emails do
  desc "Send overdue invoice digest to users with overdue invoices"
  task overdue_digest: :environment do
    puts "[#{Time.current}] Starting overdue invoice digest..."

    today = Date.today
    sent_count = 0

    User.joins(:profile).where(profiles: { paid: true }).find_each do |user|
      profile = user.profile
      next unless profile

      overdue_logs = []
      user.logs.kept.where(status: "overdue").find_each do |log|
        parsed_due = log.parsed_due_date
        next unless parsed_due && parsed_due < today

        days_overdue = (today - parsed_due).to_i
        totals = ApplicationController.helpers.calculate_log_totals(log, profile)
        amount = totals[:total_due].to_f.round(2)

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

      begin
        UserMailer.overdue_digest(user, overdue_logs).deliver_later
        sent_count += 1
        puts "  → Sent digest to #{user.email} (#{overdue_logs.size} overdue invoices)"
      rescue => e
        puts "  ✗ Failed for #{user.email}: #{e.message}"
      end
    end

    puts "[#{Time.current}] Overdue digest complete. Sent to #{sent_count} users."
  end
end
