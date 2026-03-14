class AddUniqueIndexToLogsInvoiceNumber < ActiveRecord::Migration[8.0]
  def change
    # Prevent duplicate invoice numbers per user (race condition fix)
    # Partial index: only for authenticated users (user_id IS NOT NULL)
    add_index :logs, [:user_id, :invoice_number], unique: true,
              where: "user_id IS NOT NULL AND invoice_number IS NOT NULL",
              name: "idx_logs_user_invoice_number_unique"
  end
end
