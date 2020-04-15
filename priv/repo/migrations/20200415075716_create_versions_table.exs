defmodule WraftDoc.Repo.Migrations.CreateVersionsTable do
  use Ecto.Migration

  def up do
    create table(:version) do
      add(:uuid, :uuid, null: false)
      add(:version_number, :integer, default: 1)
      add(:raw, :string)
      add(:serialized, :jsonb)
      add(:content_id, references(:content, on_delete: :delete_all))
      add(:creator_id, references(:user, on_delete: :nilify_all))
      timestamps()
    end

    create(unique_index(:version, [:version_number, :content_id], name: :version_unique_index))
  end

  def down do
    drop_if_exists(table(:version))
  end
end
