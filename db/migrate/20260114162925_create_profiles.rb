class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.string :business_name
      t.string :phone
      t.string :email
      t.string :address
      t.string :tax_id
      t.decimal :hourly_rate

      t.timestamps
    end
  end
end
