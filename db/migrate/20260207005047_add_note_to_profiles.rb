class AddNoteToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :note, :text
  end
end
