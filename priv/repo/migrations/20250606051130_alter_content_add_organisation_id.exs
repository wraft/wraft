defmodule WraftDoc.Repo.Migrations.AlterContentAddOrganisationId do
  use Ecto.Migration

  def up do
    alter table(:content) do
      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end

    execute("""
    UPDATE content AS i
    SET organisation_id = ct.organisation_id
    FROM content_type AS ct
    WHERE i.content_type_id = ct.id
    """)
  end

  def down do
    execute("UPDATE content SET organisation_id = NULL")

    alter table(:content) do
      remove(:organisation_id)
    end
  end
end
