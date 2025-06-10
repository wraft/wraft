defmodule WraftDoc.Repo.Migrations.CreateStorageItems do
  use Ecto.Migration

  def change do
    create table(:storage_items, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:display_name, :string)
      add(:item_type, :string)
      add(:path, :string)
      add(:path_hash, :string)
      add(:depth_level, :integer)
      add(:materialized_path, :string)
      add(:mime_type, :string)
      add(:file_extension, :string)
      add(:size, :integer)
      add(:checksum_sha256, :string)
      add(:version_number, :string)
      add(:is_current_version, :boolean, default: false, null: false)
      add(:classification_level, :string)
      add(:is_deleted, :boolean, default: false, null: false)
      add(:deleted_at, :utc_datetime)
      add(:sync_source, :string)
      add(:external_id, :string)
      add(:external_metadata, :map)
      add(:last_synced_at, :utc_datetime)
      add(:content_extracted, :boolean, default: false, null: false)
      add(:thumbnail_generated, :boolean, default: false, null: false)
      add(:download_count, :integer)
      add(:last_accessed_at, :utc_datetime)
      add(:metadata, :map)
      add(:parent_id, references(:storage_items, on_delete: :nothing, type: :uuid))
      add(:repository_id, references(:repositories, on_delete: :nothing, type: :uuid))
      add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
      add(:creator_id, references(:user, on_delete: :nothing, type: :uuid))

      timestamps()
    end

    create(index(:storage_items, [:parent_id]))
    create(index(:storage_items, [:repository_id]))
    create(index(:storage_items, [:organisation_id]))
    create(index(:storage_items, [:creator_id]))

    create(
      unique_index(:storage_items, [:external_id, :sync_source],
        name: :storage_items_external_id_sync_source_index
      )
    )
  end
end
