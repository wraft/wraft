defmodule WraftDoc.Repo.Migrations.CreateContentTypeRole do
  use Ecto.Migration

  def change do
    create table(:content_type_role, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :delete_all)
      )

      add(:role_id, references(:role, type: :uuid, column: :id, on_delete: :delete_all))

      timestamps()
    end
  end
end
