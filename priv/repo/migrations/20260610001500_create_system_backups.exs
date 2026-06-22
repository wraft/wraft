defmodule WraftDoc.Repo.Migrations.CreateSystemBackups do
  use Ecto.Migration

  def change do
    create table(:system_backups, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :string, null: false, default: "pending")
      add(:trigger_type, :string, null: false)
      add(:file_path, :string)
      add(:file_size, :bigint)
      add(:manifest, :map, default: %{})
      add(:error, :text)
      add(:heartbeat_at, :utc_datetime)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)

      add(
        :creator_id,
        references(:internal_user, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:system_backups, [:status]))
    create(index(:system_backups, [:inserted_at]))

    # Single-in-flight guard: a constant-expression partial unique index so
    # ANY two rows in an active state conflict (a naive index on (status)
    # would wrongly admit one pending row alongside one running row), while
    # a single row transitioning pending -> running does not conflict with
    # itself.
    execute(
      """
      CREATE UNIQUE INDEX system_backups_single_active_idx
      ON system_backups ((true))
      WHERE status IN ('pending', 'running')
      """,
      "DROP INDEX IF EXISTS system_backups_single_active_idx"
    )
  end
end
