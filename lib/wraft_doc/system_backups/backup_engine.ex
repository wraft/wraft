defmodule WraftDoc.SystemBackups.BackupEngine do
  @moduledoc """
  Builds a whole-application backup as three plaintext objects under a
  per-backup prefix (`system/backups/{id}/`) in the dedicated backup bucket:

    1. `database.dump` — `pg_dump -Fc` of the application database
       (credentials via env, never argv; validated with `pg_restore --list`
       + a size floor)
    2. `bucket.tar` — a plain tar of a per-object streamed mirror of the
       application MinIO bucket (missing objects are skipped and recorded,
       never fatal)
    3. `manifest.json` — metadata

  Each part is uploaded separately and verified by `head_object` size, so
  the admin can download the database, the bucket, or a combined on-the-fly
  tar. Artifacts are UNENCRYPTED — the backup bucket must be private/staff-only.

  The engine makes module-local `ExAws.S3` calls with explicit bucket
  arguments — the shared `WraftDoc.Client.Minio` hardcodes the app bucket
  and must not be used here (parts would land in the app bucket and
  recursive nightly backups would embed prior backups). Publishing is the
  caller's `SystemBackups.mark_completed/2` — the DB row is the publish bit.

  Refuses to run when no backup bucket is configured.
  """

  require Logger

  alias ExAws.S3

  @ex_aws Application.compile_env(:wraft_doc, [:test_module, :minio], ExAws)
  @cmd_runner Application.compile_env(
                :wraft_doc,
                [:test_module, :cmd_runner],
                WraftDoc.SystemBackups.CmdRunner.SystemCmd
              )

  # An -Fc dump of even an empty database is a few KB; anything under this
  # is a truncated/failed write masquerading as success.
  @min_dump_bytes 1_024

  # Cap the skipped-objects list persisted to the DB manifest summary; the
  # full list lives only inside the artifact's manifest.json.
  @summary_skipped_cap 100

  @doc """
  Builds and uploads the backup parts for `backup`.

  Produces three plaintext objects under the per-backup prefix
  `system/backups/{id}/`: `database.dump`, `bucket.tar`, `manifest.json`.
  Returns `{:ok, %{file_path: prefix, file_size: total, db_size,
  db_checksum, bucket_size, bucket_checksum, manifest: summary}}` or
  `{:error, reason}` with secrets scrubbed. Never publishes on failure.
  """
  def build(backup) do
    with {:ok, config} <- runtime_config(),
         {:ok, staging_dir} <- create_staging_dir() do
      try do
        run_pipeline(backup, config, staging_dir)
      after
        File.rm_rf(staging_dir)
      end
    end
  end

  defp run_pipeline(backup, config, staging_dir) do
    dump_path = Path.join(staging_dir, "database.dump")
    bucket_dir = Path.join(staging_dir, "bucket")
    bucket_tar = Path.join(staging_dir, "bucket.tar")
    manifest_path = Path.join(staging_dir, "manifest.json")
    prefix = backup_prefix(backup)

    with :ok <- check_free_disk(staging_dir, config),
         {:ok, dump_meta} <- dump_database(dump_path, config),
         {:ok, mirror_meta} <- mirror_bucket(bucket_dir, config),
         :ok <- tar_bucket(bucket_dir, bucket_tar, config),
         {:ok, manifest} <- write_manifest(manifest_path, backup, config, dump_meta, mirror_meta),
         {:ok, db_size, db_sum} <- file_facts(dump_path),
         {:ok, bucket_size, bucket_sum} <- file_facts(bucket_tar),
         :ok <- upload_part(dump_path, prefix <> "database.dump", db_size, config),
         :ok <- upload_part(bucket_tar, prefix <> "bucket.tar", bucket_size, config),
         :ok <- upload_part(manifest_path, prefix <> "manifest.json", nil, config) do
      {:ok,
       %{
         file_path: prefix,
         file_size: db_size + bucket_size,
         db_size: db_size,
         db_checksum: db_sum,
         bucket_size: bucket_size,
         bucket_checksum: bucket_sum,
         manifest: summarize_manifest(manifest)
       }}
    else
      error ->
        # A part may have uploaded before a later step failed; remove the
        # partial prefix so retention (which only sees completed rows) can't
        # leak it. delete_prefix is idempotent and safe if nothing was written.
        delete_prefix(prefix)
        error
    end
  end

  @doc "Per-backup object prefix in the backup bucket."
  def backup_prefix(backup), do: "system/backups/#{backup.id}/"

  @doc """
  Uploads a local file to a backup-bucket key (used by import). Returns
  `{:ok, size}` (verified via head_object) or `{:error, reason}`.
  """
  def put_file(local_path, key) do
    case backup_bucket() do
      nil ->
        {:error, "no backup bucket configured"}

      bucket ->
        with {:ok, %File.Stat{size: size}} <- File.stat(local_path),
             {:ok, _} <-
               local_path
               |> S3.Upload.stream_file()
               |> S3.upload(bucket, key)
               |> @ex_aws.request() do
          {:ok, size}
        else
          {:error, reason} -> {:error, "upload of #{key} failed: #{inspect(reason)}"}
        end
    end
  end

  defp runtime_config do
    settings = Application.get_env(:wraft_doc, :system_backup, [])

    backup_bucket = settings[:backup_bucket]
    database_url = System.get_env("DATABASE_URL")

    cond do
      backup_bucket in [nil, ""] ->
        {:error, "no backup bucket configured (MINIO_BACKUP_BUCKET) — refusing to run"}

      database_url in [nil, ""] ->
        {:error, "DATABASE_URL is not set — cannot run pg_dump"}

      true ->
        {:ok,
         %{
           backup_bucket: backup_bucket,
           app_bucket: System.get_env("MINIO_BUCKET"),
           database_url: database_url,
           cloak_key_label: settings[:cloak_key_label] || "v1",
           min_free_disk_bytes: settings[:min_free_disk_bytes] || 2_000_000_000
         }}
    end
  end

  defp create_staging_dir do
    {:ok, Briefly.create!(directory: true)}
  rescue
    error -> {:error, "could not create staging directory: #{Exception.message(error)}"}
  end

  defp check_free_disk(staging_dir, config) do
    floor_bytes = config.min_free_disk_bytes

    case free_disk_bytes(staging_dir) do
      {:ok, free} when free < floor_bytes ->
        {:error,
         "insufficient disk for backup staging: #{free} bytes free, " <>
           "#{floor_bytes} required"}

      _ ->
        # On parse failure we proceed: failing every backup on `df` output
        # quirks is worse than skipping the pre-flight.
        :ok
    end
  end

  defp free_disk_bytes(path) do
    # `-P` (POSIX) guarantees one line per filesystem (no wrapping on long
    # device names) and fixed column positions, so "Available" is always
    # field index 3. Without it, a wrapped row shifts the columns and the
    # parse lands on the capacity percentage.
    case @cmd_runner.cmd("df", ["-kP", path], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> List.last()
        |> String.split()
        |> Enum.at(3)
        |> case do
          nil -> :error
          avail_kb -> parse_kb(avail_kb)
        end

      _ ->
        :error
    end
  end

  defp parse_kb(value) do
    # Reject trailing junk (e.g. a stray "%" if columns still shifted) —
    # only a clean integer is a trustworthy free-space figure.
    case Integer.parse(value) do
      {kb, ""} -> {:ok, kb * 1_024}
      _ -> :error
    end
  end

  defp dump_database(dump_path, config) do
    started_at = DateTime.utc_now()
    env = pg_env(config.database_url)

    case @cmd_runner.cmd("pg_dump", ["-Fc", "--no-password", "-f", dump_path],
           env: env,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        validate_dump(dump_path, config, started_at)

      {output, status} ->
        {:error, "pg_dump failed (exit #{status}): #{scrub(output, config)}"}
    end
  end

  defp validate_dump(dump_path, config, started_at) do
    with {:ok, %File.Stat{size: size}} when size >= @min_dump_bytes <- File.stat(dump_path),
         {_output, 0} <-
           @cmd_runner.cmd("pg_restore", ["--list", dump_path], stderr_to_stdout: true) do
      {:ok, %{dump_started_at: started_at, dump_size: size}}
    else
      {:ok, %File.Stat{size: size}} ->
        {:error, "pg_dump output is suspiciously small (#{size} bytes) — treating as truncated"}

      {output, status} when is_binary(output) ->
        {:error, "pg_restore --list validation failed (exit #{status}): #{scrub(output, config)}"}

      {:error, reason} ->
        {:error, "could not stat dump file: #{inspect(reason)}"}
    end
  end

  # Credentials travel via env only — never argv, where they would be
  # visible in /proc/<pid>/cmdline, `ps`, and crash reports.
  defp pg_env(database_url) do
    uri = URI.parse(database_url)

    {user, _raw_password, password} = WraftDoc.DatabaseUrl.credentials(database_url)

    database = uri.path && String.trim_leading(uri.path, "/")

    Enum.reject(
      [
        {"PGHOST", uri.host},
        {"PGPORT", uri.port && Integer.to_string(uri.port)},
        {"PGUSER", user},
        {"PGPASSWORD", password},
        {"PGDATABASE", database}
      ],
      fn {_key, value} -> value in [nil, ""] end
    )
  end

  defp mirror_bucket(bucket_dir, config) do
    started_at = DateTime.utc_now()
    File.mkdir_p!(bucket_dir)

    keys = list_app_bucket_keys(config)

    {mirrored, skipped} =
      Enum.reduce(keys, {0, []}, fn key, {mirrored, skipped} ->
        case mirror_object(key, bucket_dir, config) do
          :ok -> {mirrored + 1, skipped}
          {:skip, reason} -> {mirrored, [%{key: key, reason: reason} | skipped]}
        end
      end)

    {:ok,
     %{
       mirror_started_at: started_at,
       mirror_finished_at: DateTime.utc_now(),
       object_count: mirrored,
       skipped_objects: Enum.reverse(skipped)
     }}
  rescue
    error -> {:error, "bucket mirror failed: #{scrub(Exception.message(error), config)}"}
  end

  defp list_app_bucket_keys(config) do
    config.app_bucket
    |> S3.list_objects()
    |> @ex_aws.stream!()
    |> Stream.map(& &1.key)
    |> Enum.reject(&excluded_key?(&1, config))
  end

  # Folder-marker keys aren't real objects. In the same-bucket fallback
  # mode (backup bucket == app bucket), prior backups and in-flight temp
  # keys must be excluded or every nightly backup would recursively embed
  # the previous N artifacts.
  defp excluded_key?(key, config) do
    String.ends_with?(key, "/") or
      (config.backup_bucket == config.app_bucket and
         (String.starts_with?(key, "system/backups/") or String.ends_with?(key, ".tmp")))
  end

  defp mirror_object(key, bucket_dir, config) do
    dest = Path.join(bucket_dir, key)

    # Defend the serving node: an object key containing ".." would let
    # Path.join escape the staging dir and write anywhere the BEAM user
    # can. S3 keys can legitimately contain "..", so verify the resolved
    # path stays inside the staging root before writing.
    if path_within?(dest, bucket_dir) do
      File.mkdir_p!(Path.dirname(dest))

      config.app_bucket
      |> S3.download_file(key, dest)
      |> @ex_aws.request()
      |> case do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("backup: skipping object #{key}: #{inspect(reason)}")
          {:skip, "download_error"}
      end
    else
      Logger.error("backup: refusing object with path-escaping key: #{key}")
      {:skip, "unsafe_key"}
    end
  rescue
    error ->
      # Missing binaries for DB-referenced keys are a known dev-environment
      # gap; a complete-but-annotated backup beats no backup.
      Logger.warning("backup: skipping object #{key}: #{Exception.message(error)}")
      {:skip, "not_found"}
  end

  defp path_within?(candidate, root) do
    expanded_root = Path.expand(root)
    expanded = Path.expand(candidate)
    expanded == expanded_root or String.starts_with?(expanded, expanded_root <> "/")
  end

  defp write_manifest(manifest_path, backup, config, dump_meta, mirror_meta) do
    manifest = %{
      backup_id: backup.id,
      created_at: DateTime.to_iso8601(DateTime.utc_now()),
      trigger_type: backup.trigger_type,
      scope: %{
        database: database_name(config),
        bucket: config.app_bucket
      },
      versions: %{
        pg_dump: tool_version("pg_dump"),
        server: server_version(),
        migration: latest_migration_version(),
        app: app_version()
      },
      cloak_key_label: config.cloak_key_label,
      layout: %{
        parts: ["database.dump", "bucket.tar", "manifest.json"],
        database_format: "pg_dump -Fc (restore with pg_restore)",
        bucket_format: "tar (extract to recover the mirrored objects)",
        encryption: "none"
      },
      db_dump: %{
        filename: "database.dump",
        size_bytes: dump_meta.dump_size,
        started_at: DateTime.to_iso8601(dump_meta.dump_started_at)
      },
      bucket_mirror: %{
        object_count: mirror_meta.object_count,
        skipped_objects: mirror_meta.skipped_objects,
        started_at: DateTime.to_iso8601(mirror_meta.mirror_started_at),
        finished_at: DateTime.to_iso8601(mirror_meta.mirror_finished_at)
      },
      consistency_note:
        "The database snapshot is transaction-consistent at dump start; the bucket mirror " <>
          "ran afterwards. Rows and objects changed between started_at timestamps may not reconcile."
    }

    case File.write(manifest_path, Jason.encode!(manifest, pretty: true)) do
      :ok -> {:ok, manifest}
      {:error, reason} -> {:error, "could not write manifest: #{inspect(reason)}"}
    end
  end

  # The DB column keeps only a small summary; tenant object keys (PII) and
  # the full skipped list live only inside the artifact's manifest.json.
  defp summarize_manifest(manifest) do
    %{
      "scope" => %{
        "database" => manifest.scope.database,
        "bucket" => manifest.scope.bucket
      },
      "versions" => %{
        "pg_dump" => manifest.versions.pg_dump,
        "server" => manifest.versions.server,
        "migration" => manifest.versions.migration,
        "app" => manifest.versions.app
      },
      "cloak_key_label" => manifest.cloak_key_label,
      "encryption_scheme" => "none",
      "db_dump_size_bytes" => manifest.db_dump.size_bytes,
      "object_count" => manifest.bucket_mirror.object_count,
      "skipped_count" => length(manifest.bucket_mirror.skipped_objects),
      "skipped_objects" =>
        manifest.bucket_mirror.skipped_objects
        |> Enum.take(@summary_skipped_cap)
        |> Enum.map(& &1.key),
      "dump_started_at" => manifest.db_dump.started_at,
      "mirror_finished_at" => manifest.bucket_mirror.finished_at
    }
  end

  defp database_name(config) do
    config.database_url |> URI.parse() |> Map.get(:path, "") |> String.trim_leading("/")
  end

  defp tool_version(executable) do
    case @cmd_runner.cmd(executable, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> "unknown"
    end
  end

  defp server_version do
    case WraftDoc.Repo.query("SHOW server_version") do
      {:ok, %{rows: [[version]]}} -> version
      _ -> "unknown"
    end
  end

  defp latest_migration_version do
    case WraftDoc.Repo.query("SELECT max(version) FROM schema_migrations") do
      {:ok, %{rows: [[version]]}} -> to_string(version)
      _ -> "unknown"
    end
  end

  defp app_version do
    case Application.spec(:wraft_doc, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  # Plain tar: the mirrored objects (PDFs/images) are already compressed,
  # so gzip would burn CPU for ~0 ratio. The DB dump is uploaded as-is.
  defp tar_bucket(bucket_dir, tar_path, config) do
    case @cmd_runner.cmd("tar", ["-cf", tar_path, "-C", bucket_dir, "."], stderr_to_stdout: true) do
      {_out, 0} ->
        :ok

      {output, status} ->
        {:error, "tar of bucket failed (exit #{status}): #{scrub(output, config)}"}
    end
  end

  defp file_facts(path) do
    with {:ok, %File.Stat{size: size}} <- File.stat(path),
         {:ok, checksum} <- sha256(path) do
      {:ok, size, checksum}
    else
      {:error, reason} -> {:error, "could not stat #{Path.basename(path)}: #{inspect(reason)}"}
    end
  end

  defp sha256(path) do
    checksum =
      path
      |> File.stream!(2_048 * 1_024)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    {:ok, checksum}
  rescue
    error -> {:error, "checksum failed: #{Exception.message(error)}"}
  end

  @doc """
  Deletes every object under a backup PREFIX (`system/backups/{id}/`) from
  the backup bucket — lists the prefix and deletes each exact key. Used by
  retention, manual delete, and the reconciled-mid-run cleanup path.
  """
  def delete_prefix(prefix) when is_binary(prefix) do
    case backup_bucket() do
      nil ->
        {:error, "no backup bucket configured"}

      bucket ->
        bucket
        |> list_keys(prefix)
        |> Enum.reduce_while(:ok, &delete_one(bucket, &1, &2))
    end
  rescue
    # list_keys uses ExAws stream!, which raises on transport errors rather
    # than returning {:error, _}. Convert to an error tuple so the retention
    # worker and the LiveView delete handler degrade gracefully.
    error -> {:error, "delete_prefix failed: #{Exception.message(error)}"}
  end

  def delete_prefix(_prefix), do: {:error, "backup prefix missing"}

  defp delete_one(bucket, key, _acc) do
    case bucket |> S3.delete_object(key) |> @ex_aws.request() do
      {:ok, _} -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  @doc "Whether an object exists in the backup bucket (head_object)."
  def artifact_exists?(key) when is_binary(key) do
    case backup_bucket() do
      nil ->
        false

      bucket ->
        bucket
        |> S3.head_object(key)
        |> @ex_aws.request()
        |> case do
          {:ok, _} -> true
          _ -> false
        end
    end
  end

  def artifact_exists?(_key), do: false

  @doc "Byte size of a backup-bucket object, or nil if absent."
  def object_size(key) when is_binary(key) do
    case backup_bucket() do
      nil ->
        nil

      bucket ->
        bucket
        |> S3.head_object(key)
        |> @ex_aws.request()
        |> case do
          {:ok, %{headers: headers}} -> content_length(headers)
          _ -> nil
        end
    end
  end

  @doc """
  Chunked stream of an object body from the backup bucket — constant
  memory for multi-GB objects (never `Minio.download/1`, which loads the
  whole object and crashes on multi-chunk streams).
  """
  def artifact_stream(key) when is_binary(key) do
    backup_bucket()
    |> S3.download_file(key, :memory)
    |> @ex_aws.stream!()
  end

  defp list_keys(bucket, prefix) do
    bucket
    |> S3.list_objects(prefix: prefix)
    |> @ex_aws.stream!()
    |> Stream.map(& &1.key)
    |> Enum.to_list()
  end

  defp backup_bucket do
    case Application.get_env(:wraft_doc, :system_backup, [])[:backup_bucket] do
      bucket when is_binary(bucket) and bucket != "" -> bucket
      _ -> nil
    end
  end

  # Uploads one part to the backup bucket and (when an expected size is
  # given) verifies it landed at that byte size via head_object.
  defp upload_part(path, key, expected_size, config) do
    with {:ok, _} <-
           path
           |> S3.Upload.stream_file()
           |> S3.upload(config.backup_bucket, key)
           |> @ex_aws.request(),
         :ok <- verify_part(key, expected_size, config) do
      :ok
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "upload of #{key} failed: #{scrub(inspect(reason), config)}"}
    end
  end

  defp verify_part(_key, nil, _config), do: :ok

  defp verify_part(key, expected_size, config) do
    config.backup_bucket
    |> S3.head_object(key)
    |> @ex_aws.request()
    |> case do
      {:ok, %{headers: headers}} ->
        case content_length(headers) do
          ^expected_size ->
            :ok

          other ->
            {:error, "#{key} size mismatch: expected #{expected_size}, got #{inspect(other)}"}
        end

      {:error, reason} ->
        {:error, "uploaded part #{key} not found on verify: #{inspect(reason)}"}
    end
  end

  defp content_length(headers) do
    headers
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(name) == "content-length", do: value
    end)
    |> case do
      nil -> nil
      value -> value |> Integer.parse() |> elem(0)
    end
  end

  # A failed run must never persist or log the connection string or its
  # password (they end up in the `error` column, logs, and Sentry).
  defp scrub(text, config) when is_binary(text) do
    candidates = [
      config.database_url | WraftDoc.DatabaseUrl.password_secrets(config.database_url)
    ]

    secrets = Enum.reject(candidates, &(&1 in [nil, ""]))

    Enum.reduce(secrets, text, &String.replace(&2, &1, "[REDACTED]"))
  end
end
