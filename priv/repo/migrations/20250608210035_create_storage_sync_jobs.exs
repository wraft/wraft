defmodule WraftDoc.Repo.Migrations.CreateStorageSyncJobs do
  use Ecto.Migration

  def change do
    create table(:storage_sync_jobs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :job_type, :string
      add :sync_source, :string
      add :status, :string
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :items_processed, :integer
      add :items_failed, :integer
      add :error_details, :map
      add :repository_id, references(:repositories, on_delete: :nothing, type: :uuid)
      add :triggered_by_id, references(:user, on_delete: :nothing, type: :uuid)

      timestamps()
    end

    create index(:storage_sync_jobs, [:repository_id])
    create index(:storage_sync_jobs, [:triggered_by_id])
  end
end
