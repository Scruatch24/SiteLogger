class CreateJoinTableLogsCategories < ActiveRecord::Migration[8.0]
  def change
    create_join_table :logs, :categories do |t|
      # t.index [:log_id, :category_id]
      # t.index [:category_id, :log_id]
    end
  end
end
