class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :icon
      t.string :icon_type
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
