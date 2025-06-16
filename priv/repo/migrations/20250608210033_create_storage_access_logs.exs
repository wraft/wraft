defmodule WraftDoc.Repo.Migrations.CreateStorageAccessLogs do
  use Ecto.Migration

  def change do
    create table(:storage_access_logs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:action, :string)
      add(:ip_address, :string)
      add(:user_agent, :text)
      add(:session_id, :string)
      add(:metadata, :map)
      add(:success, :boolean, default: false, null: false)
      add(:storage_item_id, references(:storage_items, on_delete: :nothing, type: :uuid))
      add(:storage_asset_id, references(:storage_assets, on_delete: :nothing, type: :uuid))
      add(:user_id, references(:user, on_delete: :nothing, type: :uuid))
      add(:repository_id, references(:repositories, on_delete: :nothing, type: :uuid))

      timestamps()
    end

    create(index(:storage_access_logs, [:storage_item_id]))
    create(index(:storage_access_logs, [:storage_asset_id]))
    create(index(:storage_access_logs, [:user_id]))
    create(index(:storage_access_logs, [:repository_id]))
  end
end
