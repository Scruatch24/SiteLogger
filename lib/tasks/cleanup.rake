namespace :cleanup do
  desc "Delete unconfirmed users who signed up more than 24 hours ago"
  task unconfirmed_users: :environment do
    puts "Cleaning up unconfirmed users..."

    # Find users who are not confirmed and whose confirmation link was sent more than 24 hours ago
    # We use confirmation_sent_at as the reference point
    stale_users = User.where(confirmed_at: nil)
                      .where("confirmation_sent_at < ?", 24.hours.ago)

    count = stale_users.count
    stale_users.destroy_all

    puts "Successfully deleted #{count} stale unconfirmed users."
  end
end
