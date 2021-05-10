defmodule WraftDoc.Repo.Migrations.CreateVersionsTable do
  use Ecto.Migration

  def up do
    create table(:version, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:version_number, :integer, default: 1)
      add(:raw, :string)
      add(:naration, :string)
      add(:serialized, :jsonb)
      add(:content_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:author_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end

    create(unique_index(:version, [:version_number, :content_id], name: :version_unique_index))
  end

  def down do
    drop_if_exists(table(:version))
  end
end
