class AddSenderAndRecipientInfoToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :sender_info, :text
    add_column :logs, :recipient_info, :text
  end
end
