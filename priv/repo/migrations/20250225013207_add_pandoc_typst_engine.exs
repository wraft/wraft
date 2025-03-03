defmodule WraftDoc.Repo.Migrations.AddPandocTypstEngine do
  use Ecto.Migration

  def up do
    execute("""
      INSERT INTO engine (id, name, api_route, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'Pandoc + Typst', '/api/v1/pandoc_typst_engine', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    """)

    alter table(:content) do
      add(:doc_settings, :map)
    end

    execute("""
      UPDATE content
      SET doc_settings = '{"qr":true,"toc":true,"toc_depth":3,"background":false}'::jsonb
      WHERE doc_settings IS NULL
    """)
  end

  def down do
    execute("""
      INSERT INTO engine (id, name, api_route, inserted_at, updated_at)
      VALUES (gen_random_uuid(), 'Pandoc + Typst', '/api/v1/pandoc_typst_engine', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    """)

    alter table(:content) do
      remove(:doc_settings)
    end
  end
end
