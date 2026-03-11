class CreateLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :logs do |t|
      t.string :date
      t.string :client
      t.string :time
      t.text :tasks
      t.text :products

      t.timestamps
    end
  end
end
