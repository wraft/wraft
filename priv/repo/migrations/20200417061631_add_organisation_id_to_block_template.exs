defmodule WraftDoc.Repo.Migrations.AddOrganisationIdToBlockTemplate do
  use Ecto.Migration

  def up do
    alter table(:block_template) do
      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :delete_all)
      )
    end

    create(
      unique_index(:block_template, [:title, :organisation_id],
        name: :organisation_block_template_unique_index
      )
    )
  end

  def down do
    alter table(:block_template) do
      remove(:organisation_id)
    end
  end
end
