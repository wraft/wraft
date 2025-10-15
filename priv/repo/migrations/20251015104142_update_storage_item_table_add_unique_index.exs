defmodule WraftDoc.Repo.Migrations.UpdateStorageItemTableAddUniqueIndex do
  use Ecto.Migration

  def up do
    execute("""
    CREATE UNIQUE INDEX storage_items_name_parent_id_index
    ON storage_items (name, COALESCE(parent_id::text, 'root'))
    WHERE deleted_at IS NULL;
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS storage_items_name_parent_id_index;")
  end
end
