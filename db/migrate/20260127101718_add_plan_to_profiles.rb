class AddPlanToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :plan, :string, default: "guest"
  end
end
