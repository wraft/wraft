defmodule WraftDoc.SystemBackups.Restore do
  @moduledoc """
  A restore from a `Backup`. Two target types:

    * `:local` — into a NEW database + bucket on THIS server
      (`wraft_restored_<short>` / `wraft-restored-<short>`). The live
      database and bucket are never touched.
    * `:remote` — into a database + bucket on ANOTHER site (operator
      supplies the connection). For migrating a backup to a new server.

  Remote connection secrets (DB URL, S3 secret) are encrypted at rest via
  Cloak. Lifecycle: `pending -> running -> completed | failed`; a partial
  unique index keeps at most one restore in flight.
  """
  use WraftDoc.Schema

  alias WraftDoc.EctoType.EncryptedBinaryType
  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.SystemBackups.Backup

  schema "system_backup_restores" do
    field(:status, Ecto.Enum,
      values: [:pending, :running, :completed, :failed],
      default: :pending
    )

    field(:target_type, Ecto.Enum, values: [:local, :remote], default: :local)
    field(:target_database, :string)
    field(:target_bucket, :string)

    field(:remote_database_url, EncryptedBinaryType, redact: true)
    field(:remote_s3_endpoint, :string)
    field(:remote_s3_bucket, :string)
    field(:remote_s3_access_key_id, :string)
    field(:remote_s3_secret, EncryptedBinaryType, redact: true)

    field(:error, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    belongs_to(:backup, Backup)
    belongs_to(:creator, InternalUser)

    timestamps()
  end

  def local_changeset(restore, attrs) do
    restore
    |> cast(attrs, [:backup_id, :creator_id, :target_database, :target_bucket])
    |> put_change(:target_type, :local)
    |> validate_required([:backup_id, :target_database, :target_bucket])
    |> guard_single_active()
  end

  def remote_changeset(restore, attrs) do
    restore
    |> cast(attrs, [
      :backup_id,
      :creator_id,
      :remote_database_url,
      :remote_s3_endpoint,
      :remote_s3_bucket,
      :remote_s3_access_key_id,
      :remote_s3_secret
    ])
    |> put_change(:target_type, :remote)
    |> validate_required([
      :backup_id,
      :remote_database_url,
      :remote_s3_endpoint,
      :remote_s3_bucket,
      :remote_s3_access_key_id,
      :remote_s3_secret
    ])
    |> guard_single_active()
  end

  def update_changeset(restore, attrs) do
    cast(restore, attrs, [:status, :error, :started_at, :completed_at])
  end

  defp guard_single_active(changeset) do
    unique_constraint(changeset, :status,
      name: :system_backup_restores_single_active_idx,
      message: "a restore is already in progress"
    )
  end
end
