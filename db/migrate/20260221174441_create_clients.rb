class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.text :address
      t.string :tax_id
      t.text :notes
      t.integer :invoices_count, default: 0, null: false

      t.timestamps
    end

    add_index :clients, [:user_id, :name], unique: true
    add_reference :logs, :client, foreign_key: true, null: true
  end
end
