defmodule WraftDoc.Repo.Migrations.UpdateVersionUniqueIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(:version, [:version_number, :content_id], name: :version_unique_index)
    )

    create(
      unique_index(:version, [:version_number, :content_id, :type], name: :version_unique_index)
    )
  end
end
