class AddDarkModeToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :dark_mode, :boolean
  end
end
