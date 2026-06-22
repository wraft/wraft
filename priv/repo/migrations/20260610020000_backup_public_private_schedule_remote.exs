defmodule WraftDoc.Repo.Migrations.BackupPublicPrivateScheduleRemote do
  use Ecto.Migration

  def change do
    # Remote restore ("another site") target + connection. Secrets are
    # encrypted at rest via Cloak (EncryptedBinaryType -> :binary).
    alter table(:system_backup_restores) do
      add(:target_type, :string, null: false, default: "local")
      add(:remote_database_url, :binary)
      add(:remote_s3_endpoint, :string)
      add(:remote_s3_bucket, :string)
      add(:remote_s3_access_key_id, :string)
      add(:remote_s3_secret, :binary)
    end

    # UI-configurable auto-backup schedule (singleton row). Applied by an
    # hourly checker, so changes take effect without a redeploy.
    create table(:system_backup_schedule, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:enabled, :boolean, null: false, default: false)
      add(:frequency, :string, null: false, default: "daily")
      add(:hour, :integer, null: false, default: 1)
      add(:minute, :integer, null: false, default: 30)
      # 1 (Mon) .. 7 (Sun), used only for weekly.
      add(:day_of_week, :integer, null: false, default: 1)
      add(:retention_count, :integer, null: false, default: 7)
      # Guards against double-runs within a period.
      add(:last_run_on, :date)

      timestamps()
    end
  end
end
