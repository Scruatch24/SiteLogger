class AddInvoiceNumberToLogs < ActiveRecord::Migration[8.0]
  class MigrationLog < ApplicationRecord
    self.table_name = :logs
  end

  def up
    add_column :logs, :invoice_number, :integer
    add_index :logs, [ :user_id, :invoice_number ]

    MigrationLog.reset_column_information

    # Get all distinct user_ids (including nil)
    user_ids = MigrationLog.distinct.pluck(:user_id)

    user_ids.each do |uid|
      # Iterate through logs for this user, ordered by ID (creation order)
      # This matches the previous dynamic logic: count of records <= current ID
      MigrationLog.where(user_id: uid).order(:id).each_with_index do |log, index|
        # previous logic: 1000 + count. index is 0-based, so count is index+1.
        log.update_column(:invoice_number, 1000 + index + 1)
      end
    end
  end

  def down
    remove_column :logs, :invoice_number
  end
end
