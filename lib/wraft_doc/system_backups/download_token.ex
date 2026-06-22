defmodule WraftDoc.SystemBackups.DownloadToken do
  @moduledoc """
  A short-lived, single-use download authorization for a backup artifact.

  DB-backed on purpose: a stateless `Phoenix.Token` cannot be single-use
  (replay within the window passes verification). Only the SHA-256 hash
  of the token is stored; consumption is an atomic delete, so reuse is
  detectable and the guarantee holds across nodes.
  """
  use WraftDoc.Schema

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.SystemBackups.Backup

  @parts ~w(db bucket full)

  schema "system_backup_download_tokens" do
    field(:token_hash, :string)
    field(:part, :string, default: "full")
    field(:expires_at, :utc_datetime)

    belongs_to(:backup, Backup)
    belongs_to(:admin, InternalUser)

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token_hash, :part, :expires_at, :backup_id, :admin_id])
    |> validate_required([:token_hash, :part, :expires_at, :backup_id, :admin_id])
    |> validate_inclusion(:part, @parts)
    |> unique_constraint(:token_hash)
  end
end
