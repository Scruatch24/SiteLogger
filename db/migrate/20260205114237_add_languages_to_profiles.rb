class AddLanguagesToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :system_language, :string
    add_column :profiles, :document_language, :string
  end
end
