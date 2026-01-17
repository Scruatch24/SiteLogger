class AddDueDateToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :due_date, :string
  end
end
