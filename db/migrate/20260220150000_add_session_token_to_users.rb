class AddSessionTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :session_token, :string
  end
end
