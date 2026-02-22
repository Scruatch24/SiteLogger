namespace :logs do
  desc "Backfill cached_total_due for all existing logs"
  task backfill_cached_total_due: :environment do
    total = Log.count
    updated = 0
    errors = 0

    puts "Backfilling cached_total_due for #{total} logs..."

    Log.find_each do |log|
      profile = log.user&.profile || Profile.new
      totals = ApplicationController.helpers.calculate_log_totals(log, profile)
      amount = totals[:total_due].to_f.round(2)
      log.update_column(:cached_total_due, amount)
      updated += 1
      print "." if updated % 50 == 0
    rescue => e
      errors += 1
      puts "\nError on log #{log.id}: #{e.message}"
    end

    puts "\nDone! Updated: #{updated}, Errors: #{errors}"
  end
end
