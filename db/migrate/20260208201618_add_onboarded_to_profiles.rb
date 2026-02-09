class AddOnboardedToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :onboarded, :boolean
  end
end
