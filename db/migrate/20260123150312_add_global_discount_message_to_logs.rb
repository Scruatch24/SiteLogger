class AddGlobalDiscountMessageToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :global_discount_message, :string
  end
end
