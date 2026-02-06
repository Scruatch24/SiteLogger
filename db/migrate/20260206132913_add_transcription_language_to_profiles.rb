class AddTranscriptionLanguageToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :transcription_language, :string
  end
end
