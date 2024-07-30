defmodule WraftDoc.Repo.Migrations.CreateDashboardStatsView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE MATERIALIZED VIEW dashboard_stats AS
    SELECT
      ct.organisation_id,
      COUNT(i.id) AS total_documents,
      COUNT(i.id) FILTER (WHERE date_trunc('day', i.inserted_at) = current_date) AS daily_documents,
      COUNT(i.id) FILTER (WHERE i.approval_status = false) AS pending_approvals
    FROM
      content i
    JOIN
      content_type ct ON i.content_type_id = ct.id
    GROUP BY
      ct.organisation_id
    """)
  end

  def down do
    execute("DROP MATERIALIZED VIEW IF EXISTS dashboard_stats")
  end
end
