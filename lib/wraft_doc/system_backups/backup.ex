defmodule WraftDoc.SystemBackups.Backup do
  @moduledoc """
  A whole-application backup run: a `pg_dump` of the application database
  plus a mirror of the application MinIO bucket. The parts are stored as
  separate plaintext objects under a per-backup prefix (`file_path`) in
  the dedicated backup bucket:

    * `<prefix>/database.dump` — pg_dump custom format
    * `<prefix>/bucket.tar`    — tar of the mirrored bucket
    * `<prefix>/manifest.json` — metadata

  Each part's size and checksum is tracked so downloads (DB-only,
  bucket-only, or a combined on-the-fly tar) work without storing a
  duplicate combined artifact.

  Lifecycle: `pending -> running -> completed | failed`; `completed`
  rows may later become `deleted` (retention or manual delete). The
  `completed` status is the publish bit. `heartbeat_at` is refreshed by
  the worker's timer; reconciliation flips only stale in-flight rows to
  `failed`.
  """
  use WraftDoc.Schema

  alias WraftDoc.InternalUsers.InternalUser

  schema "system_backups" do
    field(:status, Ecto.Enum,
      values: [:pending, :running, :completed, :failed, :deleted],
      default: :pending
    )

    field(:trigger_type, Ecto.Enum, values: [:manual, :scheduled, :imported])
    field(:file_path, :string)
    field(:file_size, :integer)
    field(:db_size, :integer)
    field(:db_checksum, :string)
    field(:bucket_size, :integer)
    field(:bucket_checksum, :string)
    field(:manifest, :map, default: %{})
    field(:error, :string)
    field(:heartbeat_at, :utc_datetime)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    belongs_to(:creator, InternalUser)

    timestamps()
  end

  def changeset(backup, attrs) do
    backup
    |> cast(attrs, [:trigger_type, :creator_id])
    |> validate_required([:trigger_type])
    |> unique_constraint(:status,
      name: :system_backups_single_active_idx,
      message: "a backup is already in progress"
    )
  end

  def update_changeset(backup, attrs) do
    cast(backup, attrs, [
      :status,
      :file_path,
      :file_size,
      :db_size,
      :db_checksum,
      :bucket_size,
      :bucket_checksum,
      :manifest,
      :error,
      :heartbeat_at,
      :started_at,
      :completed_at
    ])
  end
end
