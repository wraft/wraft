defmodule WraftDoc.SystemBackups.ErrorMessage do
  @moduledoc """
  Translates raw backup/restore failure strings into safe, human-readable
  messages for operators.

  Raw failures come from shelling out (`pg_dump`/`pg_restore`/`createdb`) and
  from the object-storage client, and often embed internal detail (exit codes,
  tuples, XML error bodies). `humanize/1` maps the known failure shapes to a
  fixed operator-facing sentence and falls back to a generic message for
  anything unrecognised, so raw internals are never surfaced to the UI.

  Ordering matters: more specific markers (storage-full, missing bucket,
  unreachable host) are matched before the generic "upload/download failed"
  catch-alls.
  """

  @generic "Something went wrong while processing the backup. Please check the server logs."

  # First matching rule wins, so order from most to least specific. `:contains`
  # markers are matched anywhere; `:starts_with` markers only as a prefix.
  @rules [
    {:contains, "XMinioStorageFull", "The storage server is out of disk space."},
    {:contains, "NoSuchBucket", "The configured storage bucket does not exist."},
    {:contains, "econnrefused",
     "Could not reach the storage server. Check that it is running and reachable."},
    {:contains, "no backup bucket configured",
     "No backup storage bucket is configured (set MINIO_BACKUP_BUCKET)."},
    {:contains, "insufficient disk for backup staging",
     "Not enough free disk space on the app server to stage the backup."},
    {:contains, "pg_dump failed", "Exporting the database failed."},
    {:contains, "pg_restore failed", "Loading the database from the backup failed."},
    {:contains, "createdb failed", "Could not create the new database."},
    {:starts_with, "download of", "Downloading the backup from the storage server failed."},
    {:starts_with, "upload of", "Uploading the backup to the storage server failed."}
  ]

  @spec humanize(String.t() | nil) :: String.t() | nil
  def humanize(nil), do: nil
  def humanize(""), do: nil

  def humanize(error) when is_binary(error) do
    Enum.find_value(@rules, @generic, fn {kind, marker, message} ->
      if matches?(kind, error, marker), do: message
    end)
  end

  defp matches?(:contains, error, marker), do: String.contains?(error, marker)
  defp matches?(:starts_with, error, marker), do: String.starts_with?(error, marker)
end
