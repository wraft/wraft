defmodule WraftDoc.Repo.Migrations.ConnectDocumentWithVendor do
  use Ecto.Migration

  def up do
    alter table(:content) do
      remove(:vendor_id, references(:vendors))
    end

    create table(:vendors_contents, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:vendor_id, references(:vendors, type: :uuid, on_delete: :nilify_all))
      add(:content_id, references(:content, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(index(:vendors_contents, [:vendor_id]))
    create(index(:vendors_contents, [:content_id]))
    create(unique_index(:vendors_contents, [:vendor_id, :content_id]))
  end

  def down do
    # Drop the vendors_contents table and its indexes
    drop(index(:vendors_contents, [:vendor_id]))
    drop(index(:vendors_contents, [:content_id]))
    drop(unique_index(:vendors_contents, [:vendor_id, :content_id]))
    drop(table(:vendors_contents))

    # Add the vendor_id column back to content
    alter table(:content) do
      add(:vendor_id, references(:vendors, type: :uuid, on_delete: :nilify_all))
    end
  end
end
