defmodule WraftDocWeb.BackupDownloadController do
  @moduledoc """
  Token-gated, streamed, audited download of system backup parts.

  A backup is stored as three plaintext objects under a per-backup prefix
  (`database.dump`, `bucket.tar`, `manifest.json`). The admin can download:

    * `db`     — the Postgres dump (`pg_restore` format)
    * `bucket` — the tar of mirrored objects
    * `full`   — a combined tar of all parts, assembled on the fly

  Two-step flow per part (never a presigned/shareable URL): a CSRF-protected
  POST mints a ≤60s single-use token scoped to admin + backup + part, then
  the streaming GET consumes it and streams with constant memory. Every
  attempt (allowed or denied) is audited.
  """
  use WraftDocWeb, :controller

  require Logger

  alias WraftDoc.SystemBackups

  @backups_path "/admin/backups"
  @parts ~w(db bucket full)

  def authorize(conn, %{"id" => id, "part" => part}) when part in @parts do
    admin = conn.assigns.admin_session

    case SystemBackups.get_backup(id) do
      nil ->
        deny(conn, nil, "backup not found", :not_found)

      %{status: :completed} = backup ->
        if parts_present?(backup, part) do
          mint_and_redirect(conn, admin, backup, part)
        else
          deny(conn, backup, "artifact missing from storage", :gone)
        end

      backup ->
        deny(conn, backup, "backup is #{backup.status}, not downloadable", :conflict)
    end
  end

  def authorize(conn, %{"id" => id}),
    do: deny(conn, %{id: id}, "unknown download part", :bad_request)

  def download(conn, %{"id" => id, "part" => part} = params) when part in @parts do
    admin = conn.assigns.admin_session

    with %{status: :completed} = backup <- SystemBackups.get_backup(id),
         true <- parts_present?(backup, part),
         :ok <- SystemBackups.claim_download_token(params["token"], admin.id, backup.id, part) do
      audit(conn, :download_allowed, backup, "streaming #{part} of #{backup.file_path}")
      stream_part(conn, backup, part)
    else
      nil ->
        deny(conn, nil, "backup not found", :not_found)

      %{status: status} ->
        deny(conn, %{id: id}, "backup is #{status}, not downloadable", :conflict)

      false ->
        deny(conn, %{id: id}, "artifact missing from storage", :gone)

      :error ->
        deny(conn, %{id: id}, "invalid, expired, or already-used download token", :forbidden)
    end
  end

  def download(conn, %{"id" => id}),
    do: deny(conn, %{id: id}, "unknown download part", :bad_request)

  defp mint_and_redirect(conn, admin, backup, part) do
    case SystemBackups.create_download_token(admin, backup, part) do
      {:ok, raw_token} ->
        audit(conn, :download_authorized, backup, "token minted (#{part})")
        redirect(conn, to: "#{@backups_path}/#{backup.id}/download/#{part}?token=#{raw_token}")

      {:error, _reason} ->
        deny(conn, backup, "could not mint download token", :internal_server_error)
    end
  end

  defp stream_part(conn, backup, "full") do
    # Use the authoritative stored sizes for the part lookup (db/bucket were
    # head-verified at upload). manifest is tiny — a live HEAD is fine. A nil
    # size means a part is missing/unsized; refuse rather than stream a partial
    # archive. (Zip CRC/size land in each entry's trailing data descriptor, so
    # the sizes here only gate availability, not the archive framing.)
    parts = [
      {:db, "database.dump", backup.db_size},
      {:bucket, "bucket.tar", backup.bucket_size},
      {:manifest, "manifest.json", SystemBackups.object_size(part_key(backup, :manifest))}
    ]

    if Enum.any?(parts, fn {_part, _name, size} -> is_nil(size) end) do
      deny(conn, backup, "a backup part is missing or has unknown size", :gone)
    else
      conn
      |> download_headers(SystemBackups.part_filename(backup, :full))
      |> send_chunked(200)
      |> stream_enumerable(SystemBackups.ZipStream.stream(archive_entries(backup, parts)))
    end
  end

  defp stream_part(conn, backup, part) do
    key = SystemBackups.part_key(backup, String.to_existing_atom(part))
    filename = SystemBackups.part_filename(backup, String.to_existing_atom(part))

    conn
    |> download_headers(filename)
    |> send_chunked(200)
    |> stream_enumerable(SystemBackups.artifact_stream(key))
  end

  defp archive_entries(backup, parts) do
    Enum.map(parts, fn {part, name, size} ->
      %{name: name, size: size, stream: SystemBackups.artifact_stream(part_key(backup, part))}
    end)
  end

  defp part_key(backup, part), do: SystemBackups.part_key(backup, part)

  defp download_headers(conn, filename) do
    conn
    |> put_resp_content_type("application/octet-stream")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> put_resp_header("cache-control", "no-store")
    # Disable reverse-proxy buffering of the chunked stream.
    |> put_resp_header("x-accel-buffering", "no")
  end

  defp stream_enumerable(conn, enumerable) do
    Enum.reduce_while(enumerable, conn, fn part, conn ->
      case chunk(conn, part) do
        {:ok, conn} ->
          {:cont, conn}

        {:error, reason} ->
          Logger.warning("backup download interrupted mid-stream: #{inspect(reason)}")
          {:halt, conn}
      end
    end)
  rescue
    error ->
      Logger.error("backup download stream failed: #{Exception.message(error)}")
      conn
  end

  defp parts_present?(backup, "full") do
    parts_present?(backup, "db") and parts_present?(backup, "bucket") and
      parts_present?(backup, "manifest")
  end

  defp parts_present?(backup, part) do
    SystemBackups.artifact_exists?(SystemBackups.part_key(backup, String.to_existing_atom(part)))
  end

  defp deny(conn, backup, detail, status) do
    audit(conn, :download_denied, backup, detail)

    if conn.method == "POST" do
      conn
      |> put_flash(:error, "Download refused: #{detail}.")
      |> redirect(to: @backups_path)
    else
      conn
      |> put_status(status)
      |> text("Download refused: #{detail}")
    end
  end

  defp audit(conn, event, backup, detail) do
    SystemBackups.record_download_event(event, %{
      backup_id: backup && Map.get(backup, :id),
      admin_id: conn.assigns.admin_session.id,
      ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
      user_agent: conn |> get_req_header("user-agent") |> List.first(),
      detail: detail
    })
  end
end
