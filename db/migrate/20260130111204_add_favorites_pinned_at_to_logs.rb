class AddFavoritesPinnedAtToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :favorites_pinned_at, :datetime
  end
end
