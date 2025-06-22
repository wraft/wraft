defmodule WraftDoc.Repo.Migrations.CreateDocumentsByContentTypeStatsView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE MATERIALIZED VIEW documents_by_content_type_stats AS
    SELECT
      ct.organisation_id,
      ct.id::text AS id,
      ct.name AS name,
      ct.color AS color,
      COUNT(i.id) AS count
    FROM
      content_type ct
    LEFT JOIN
      content i ON i.content_type_id = ct.id
    GROUP BY
      ct.organisation_id, ct.id, ct.name, ct.color
    ORDER BY
      ct.name
    """)
  end

  def down do
    execute("DROP MATERIALIZED VIEW IF EXISTS documents_by_content_type_stats")
  end
end
