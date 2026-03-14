return unless Rails.env.production?
return if ENV["ENABLE_SCHEDULER"] == "false"
return if defined?(Rails::Console)
return if File.basename($PROGRAM_NAME) == "rake"

Rails.application.config.after_initialize do
  scheduler = Rufus::Scheduler.singleton

  # Daily overdue invoice digest — runs at 08:00 UTC (adjust as needed)
  scheduler.cron "0 8 * * *" do
    Rails.logger.info "[Scheduler] Enqueuing OverdueDigestJob at #{Time.current}"
    OverdueDigestJob.perform_later
  end

  Rails.logger.info "[Scheduler] rufus-scheduler started — overdue digest scheduled at 08:00 UTC daily"
end
