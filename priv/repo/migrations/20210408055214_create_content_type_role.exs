defmodule WraftDoc.Repo.Migrations.CreateContentTypeRole do
  use Ecto.Migration

  def change do
    create table(:content_type_role) do
      add :uuid, :uuid, null: false, autogenerate: true
      add :content_type_id, references(:content_type, on_delete: :delete_all)
      add :role_id, references(:role, on_delete: :delete_all)

      timestamps()
     end
  end
end
