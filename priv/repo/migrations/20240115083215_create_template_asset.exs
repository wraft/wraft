defmodule WraftDoc.Repo.Migrations.CreateTemplateAsset do
  use Ecto.Migration

  def change do
    create table(:template_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:zip_file, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end
end
