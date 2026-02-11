class AddPaddleFieldsToProfiles < ActiveRecord::Migration[8.0]
  def change
    change_table :profiles, bulk: true do |t|
      t.string :paddle_subscription_id
      t.string :paddle_price_id
      t.string :paddle_customer_email
      t.string :paddle_subscription_status
      t.datetime :paddle_next_bill_at
    end

    add_index :profiles, :paddle_subscription_id
    add_index :profiles, :paddle_customer_email
  end
end
