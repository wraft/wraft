defmodule WraftDoc.Repo.Migrations.CreateFontTable do
  @moduledoc false
  use Ecto.Migration

  def up do
    create table(:fonts, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(
      unique_index(:fonts, [:name, :organisation_id], name: :font_name_organisation_id_index)
    )

    create(index(:fonts, [:organisation_id]))
    create(index(:fonts, [:creator_id]))
  end

  def down do
    drop(table(:fonts))
  end
end
