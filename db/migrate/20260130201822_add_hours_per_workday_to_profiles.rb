class AddHoursPerWorkdayToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :hours_per_workday, :integer, default: 8
  end
end
