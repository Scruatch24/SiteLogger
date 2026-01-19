class AddHourlyRateToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :hourly_rate, :decimal
  end
end
