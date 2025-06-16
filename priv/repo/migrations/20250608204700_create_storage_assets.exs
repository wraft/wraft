defmodule WraftDoc.Repo.Migrations.CreateStorageAssets do
  use Ecto.Migration

  def change do
    create table(:storage_assets, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:filename, :string)
      add(:storage_key, :string)
      add(:storage_backend, :string)
      add(:file_size, :integer)
      add(:checksum_sha256, :string)
      add(:mime_type, :string)
      add(:encryption_key_id, :string)
      add(:compression_type, :string)
      add(:thumbnail_path, :string)
      add(:preview_path, :string)
      add(:processing_status, :string)
      add(:upload_completed_at, :utc_datetime)
      add(:storage_item_id, references(:storage_items, on_delete: :nothing, type: :uuid))
      add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
      add(:creator_id, references(:user, on_delete: :nothing, type: :uuid))

      timestamps()
    end

    create(index(:storage_assets, [:storage_item_id]))
    create(index(:storage_assets, [:organisation_id]))
    create(index(:storage_assets, [:creator_id]))
  end
end
