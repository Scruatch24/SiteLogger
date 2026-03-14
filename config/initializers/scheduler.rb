return unless Rails.env.production?
return if ENV["ENABLE_SCHEDULER"] == "false"
return if defined?(Rails::Console)
return if File.basename($PROGRAM_NAME) == "rake"

Rails.application.config.after_initialize do
  scheduler = Rufus::Scheduler.singleton

  # Daily overdue invoice digest — runs at 08:00 UTC
  scheduler.cron "0 8 * * *" do
    Rails.logger.info "[Scheduler] Enqueuing OverdueDigestJob at #{Time.current}"
    OverdueDigestJob.perform_later
  end

  # Monthly activity digest — runs on the 1st of each month at 09:00 UTC
  scheduler.cron "0 9 1 * *" do
    Rails.logger.info "[Scheduler] Enqueuing ActivityDigestJob at #{Time.current}"
    ActivityDigestJob.perform_later
  end

  # Daily renewal reminder — checks for subscriptions renewing in 3 days, runs at 09:30 UTC
  scheduler.cron "30 9 * * *" do
    Rails.logger.info "[Scheduler] Enqueuing RenewalReminderJob at #{Time.current}"
    RenewalReminderJob.perform_later
  end

  Rails.logger.info "[Scheduler] rufus-scheduler started — overdue digest @08:00, activity digest @09:00 on 1st, renewal reminders @09:30 UTC daily"
end
