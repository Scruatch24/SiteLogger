class SeedClientsFromLogs < ActiveRecord::Migration[8.0]
  def up
    # For each user, find unique client names from their logs and create Client records
    execute <<-SQL
      INSERT INTO clients (user_id, name, invoices_count, created_at, updated_at)
      SELECT l.user_id, l.client, COUNT(*) AS invoices_count, MIN(l.created_at), NOW()
      FROM logs l
      WHERE l.user_id IS NOT NULL
        AND l.client IS NOT NULL
        AND l.client != ''
        AND l.deleted_at IS NULL
      GROUP BY l.user_id, l.client
      ON CONFLICT (user_id, name) DO NOTHING;
    SQL

    # Link existing logs to their newly created client records
    execute <<-SQL
      UPDATE logs
      SET client_id = clients.id
      FROM clients
      WHERE logs.user_id = clients.user_id
        AND logs.client = clients.name
        AND logs.client_id IS NULL
        AND logs.deleted_at IS NULL;
    SQL
  end

  def down
    execute "UPDATE logs SET client_id = NULL;"
    execute "DELETE FROM clients;"
  end
end
