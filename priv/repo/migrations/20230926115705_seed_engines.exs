defmodule WraftDoc.Repo.Migrations.SeedEngines do
  use Ecto.Migration

  def change do
    execute("""
      INSERT INTO engine (id, name, api_route, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'PDF', '/api/v1/pdf_engine', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    """)

    execute("""
      INSERT INTO engine (id, name, api_route, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'LaTex', '/api/v1/latex_engine', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    """)

    execute("""
      INSERT INTO engine (id, name, api_route, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'Pandoc', '/api/v1/pandoc_engine', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM plan WHERE name in ('PDF', 'LaTex', 'Pandoc')")
  end
end
