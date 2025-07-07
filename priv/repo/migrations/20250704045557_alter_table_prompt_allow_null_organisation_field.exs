defmodule WraftDoc.Repo.Migrations.AlterTablePromptAllowNullOrganisationField do
  use Ecto.Migration

  def up do
    drop(constraint(:prompt, "prompt_organisation_id_fkey"))
    drop(constraint(:prompt, "prompt_creator_id_fkey"))
    drop(index(:prompt, [:title]))

    alter table(:prompt) do
      modify(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all),
        null: true
      )

      modify(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all), null: true)
    end

    create(unique_index(:prompt, [:title, :organisation_id], name: :unique_prompt_title_per_org))
  end

  def down do
    drop(unique_index(:prompt, [:title, :organisation_id], name: :unique_prompt_title_per_org))

    drop(constraint(:prompt, "prompt_organisation_id_fkey"))
    drop(constraint(:prompt, "prompt_creator_id_fkey"))

    alter table(:prompt) do
      modify(:organisation_id, references(:organisation, type: :uuid), null: false)
      modify(:creator_id, references(:user, type: :uuid), null: false)
    end

    create(index(:prompt, [:title]))
  end
end
