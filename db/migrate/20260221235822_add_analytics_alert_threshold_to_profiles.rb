class AddAnalyticsAlertThresholdToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :analytics_alert_threshold, :decimal, precision: 12, scale: 2, default: 5000
  end
end
