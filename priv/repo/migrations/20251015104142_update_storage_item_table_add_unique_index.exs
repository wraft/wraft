defmodule WraftDoc.Repo.Migrations.UpdateStorageItemTableAddUniqueIndex do
  use Ecto.Migration

  def up do
    alter table(:storage_items) do
      add(:upload_status, :string, default: "processing")
    end

    execute("DROP INDEX IF EXISTS storage_items_external_id_sync_source_index;")

    execute("""
    CREATE UNIQUE INDEX storage_items_name_parent_id_index
    ON storage_items (name, COALESCE(parent_id::text, 'root'))
    WHERE deleted_at IS NULL;
    """)

    execute("""
    CREATE INDEX idx_storage_items_parent_org
    ON storage_items (parent_id, organisation_id)
    WHERE is_deleted = false;
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS storage_items_name_parent_id_index;")
    execute("DROP INDEX IF EXISTS idx_storage_items_parent_org;")

    alter table(:storage_items) do
      remove(:upload_status)
    end

    create(
      unique_index(:storage_items, [:external_id, :sync_source],
        name: :storage_items_external_id_sync_source_index
      )
    )
  end
end
