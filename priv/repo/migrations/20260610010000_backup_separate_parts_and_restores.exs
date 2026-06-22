defmodule WraftDoc.Repo.Migrations.BackupSeparatePartsAndRestores do
  use Ecto.Migration

  def change do
    # Artifacts are now plaintext, stored as separate objects under a
    # per-backup prefix (file_path holds that prefix). Track each part's
    # size and checksum so downloads and the on-the-fly combined tar work.
    alter table(:system_backups) do
      add(:db_size, :bigint)
      add(:db_checksum, :string)
      add(:bucket_size, :bigint)
      add(:bucket_checksum, :string)
    end

    # The single-use download token now scopes to a part (db | bucket | full).
    alter table(:system_backup_download_tokens) do
      add(:part, :string, null: false, default: "full")
    end

    # Restore runs: always into a NEW target database + bucket, never the
    # live ones. Tracked like a backup with its own lifecycle.
    create table(:system_backup_restores, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :string, null: false, default: "pending")
      add(:target_database, :string)
      add(:target_bucket, :string)
      add(:error, :text)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)

      add(
        :backup_id,
        references(:system_backups, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(
        :creator_id,
        references(:internal_user, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:system_backup_restores, [:status]))
    create(index(:system_backup_restores, [:inserted_at]))

    # Only one restore in flight at a time (they are heavy: createdb +
    # pg_restore + bucket mirror).
    execute(
      """
      CREATE UNIQUE INDEX system_backup_restores_single_active_idx
      ON system_backup_restores ((true))
      WHERE status IN ('pending', 'running')
      """,
      "DROP INDEX IF EXISTS system_backup_restores_single_active_idx"
    )
  end
end
