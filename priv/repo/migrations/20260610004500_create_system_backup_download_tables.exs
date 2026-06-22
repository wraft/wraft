defmodule WraftDoc.Repo.Migrations.CreateSystemBackupDownloadTables do
  use Ecto.Migration

  def change do
    # Single-use download tokens: DB-backed (multi-node-safe) so consumption
    # is an atomic delete — a stateless signed token cannot be single-use.
    create table(:system_backup_download_tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:token_hash, :string, null: false)
      add(:expires_at, :utc_datetime, null: false)

      add(
        :backup_id,
        references(:system_backups, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      add(
        :admin_id,
        references(:internal_user, type: :uuid, column: :id, on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(unique_index(:system_backup_download_tokens, [:token_hash]))
    create(index(:system_backup_download_tokens, [:expires_at]))

    # Download audit trail: every mint and every allowed/denied stream
    # attempt, with actor, IP, and user agent (R7).
    create table(:system_backup_events, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:event, :string, null: false)
      add(:detail, :string)
      add(:ip, :string)
      add(:user_agent, :string)

      add(
        :backup_id,
        references(:system_backups, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(
        :admin_id,
        references(:internal_user, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:system_backup_events, [:backup_id]))
    create(index(:system_backup_events, [:inserted_at]))
  end
end
