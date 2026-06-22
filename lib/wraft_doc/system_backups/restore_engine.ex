defmodule WraftDoc.SystemBackups.RestoreEngine do
  @moduledoc """
  Restores a backup into a target database + bucket. Two modes:

    * `:local` — a NEW database + bucket on THIS server
      (`wraft_restored_<short>` / `wraft-restored-<short>`); the live
      database and bucket are never touched. Needs CREATEDB.
    * `:remote` — a database + bucket on ANOTHER site (the operator
      supplies the Postgres URL and the S3/MinIO endpoint + bucket +
      credentials). For migrating a backup to a new server. `pg_restore`
      runs with `--clean --if-exists` so the remote DB can already exist.

  Steps: download the parts (database.dump, bucket.tar), pg_restore the
  dump, then mirror the extracted objects into the target bucket.
  """

  require Logger

  alias ExAws.S3
  alias WraftDoc.SystemBackups.Backup
  alias WraftDoc.SystemBackups.RemoteTarget

  @ex_aws Application.compile_env(:wraft_doc, [:test_module, :minio], ExAws)
  @cmd_runner Application.compile_env(
                :wraft_doc,
                [:test_module, :cmd_runner],
                WraftDoc.SystemBackups.CmdRunner.SystemCmd
              )

  @doc "Runs the restore. Returns `:ok` or `{:error, reason}` (scrubbed)."
  def run(restore, %Backup{} = backup) do
    with {:ok, source} <- source_config(),
         {:ok, target} <- target_config(restore),
         {:ok, staging} <- staging_dir() do
      try do
        do_run(backup, source, target, staging)
      after
        File.rm_rf(staging)
      end
    end
  end

  defp do_run(backup, source, target, staging) do
    dump_path = Path.join(staging, "database.dump")
    bucket_dir = Path.join(staging, "bucket")
    File.mkdir_p!(bucket_dir)

    with :ok <- download(source, backup.file_path <> "database.dump", dump_path),
         :ok <- ensure_database(target),
         :ok <- restore_database(target, dump_path),
         :ok <-
           download_and_extract(source, backup.file_path <> "bucket.tar", staging, bucket_dir),
         :ok <- ensure_bucket(target) do
      upload_tree(bucket_dir, target)
    end
  end

  defp source_config do
    case Application.get_env(:wraft_doc, :system_backup, [])[:backup_bucket] do
      bucket when is_binary(bucket) and bucket != "" ->
        {:ok, %{bucket: bucket, ex_aws_overrides: []}}

      _ ->
        {:error, "no backup bucket configured"}
    end
  end

  defp target_config(%{target_type: :local} = restore) do
    database_url = System.get_env("DATABASE_URL")

    if database_url in [nil, ""] do
      {:error, "DATABASE_URL is not set"}
    else
      {:ok,
       %{
         type: :local,
         create_db: true,
         pg_env: pg_env(database_url, restore.target_database),
         maintenance_env: pg_env(database_url, "postgres"),
         database: restore.target_database,
         bucket: restore.target_bucket,
         ex_aws_overrides: []
       }}
    end
  end

  defp target_config(%{target_type: :remote} = restore) do
    uri = URI.parse(restore.remote_database_url)
    database = uri.path && String.trim_leading(uri.path, "/")

    case RemoteTarget.pin_host(uri.host) do
      {:ok, hostaddr} ->
        {:ok,
         %{
           type: :remote,
           create_db: false,
           pg_env: pg_env(restore.remote_database_url, database, hostaddr),
           database: database,
           bucket: restore.remote_s3_bucket,
           ex_aws_overrides: remote_ex_aws(restore)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp remote_ex_aws(restore) do
    %{scheme: scheme, host: host, port: port} = parse_endpoint(restore.remote_s3_endpoint)

    [
      access_key_id: restore.remote_s3_access_key_id,
      secret_access_key: restore.remote_s3_secret,
      scheme: scheme,
      host: host,
      port: port
    ]
  end

  defp parse_endpoint(endpoint) do
    uri = URI.parse(endpoint)
    scheme = (uri.scheme || "https") <> "://"
    port = uri.port || if(uri.scheme == "http", do: 80, else: 443)
    %{scheme: scheme, host: uri.host || endpoint, port: port}
  end

  defp staging_dir do
    {:ok, Briefly.create!(directory: true)}
  rescue
    error -> {:error, "could not create staging directory: #{Exception.message(error)}"}
  end

  defp ensure_database(%{create_db: false}), do: :ok

  defp ensure_database(%{database: db, maintenance_env: env} = target) do
    case @cmd_runner.cmd("createdb", [db], env: env, stderr_to_stdout: true) do
      {_out, 0} -> :ok
      {output, status} -> {:error, "createdb failed (exit #{status}): #{scrub(output, target)}"}
    end
  end

  # --exit-on-error stops at the first real error, so a clean restore exits 0
  # and any error exits non-zero. Without it pg_restore continues past errors
  # and still exits 1, which would let a half-restored DB look successful.
  # --no-owner/--no-privileges already suppress the benign ownership errors.
  defp restore_database(%{type: :local} = target, dump_path) do
    pg_restore(target, [
      "--no-owner",
      "--no-privileges",
      "--exit-on-error",
      "--dbname",
      target.database,
      dump_path
    ])
  end

  defp restore_database(%{type: :remote} = target, dump_path) do
    # Remote DB may already exist: clean it first.
    pg_restore(target, [
      "--no-owner",
      "--no-privileges",
      "--clean",
      "--if-exists",
      "--exit-on-error",
      "--dbname",
      target.database,
      dump_path
    ])
  end

  defp pg_restore(target, args) do
    case @cmd_runner.cmd("pg_restore", args, env: target.pg_env, stderr_to_stdout: true) do
      {_out, 0} -> :ok
      {output, status} -> {:error, "pg_restore failed (exit #{status}): #{scrub(output, target)}"}
    end
  end

  defp pg_env(database_url, database, hostaddr \\ nil) do
    uri = URI.parse(database_url)
    {user, _raw, password} = WraftDoc.DatabaseUrl.credentials(database_url)

    Enum.reject(
      [
        {"PGHOST", uri.host},
        # Pin the validated IP for remote targets so pg_restore connects to the
        # resolved address instead of re-resolving the hostname (DNS rebinding).
        # PGHOST stays set for TLS/cert verification. nil for local targets.
        {"PGHOSTADDR", hostaddr},
        {"PGPORT", uri.port && Integer.to_string(uri.port)},
        {"PGUSER", user},
        {"PGPASSWORD", password},
        {"PGDATABASE", database}
      ],
      fn {_k, v} -> v in [nil, ""] end
    )
  end

  defp download(source, key, dest) do
    source.bucket
    |> S3.download_file(key, dest)
    |> @ex_aws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "download of #{key} failed: #{inspect(reason)}"}
    end
  end

  defp download_and_extract(source, key, staging, bucket_dir) do
    tar_path = Path.join(staging, Path.basename(key))

    with :ok <- download(source, key, tar_path),
         {_out, 0} <-
           @cmd_runner.cmd("tar", ["-xf", tar_path, "-C", bucket_dir], stderr_to_stdout: true) do
      :ok
    else
      {output, status} when is_binary(output) ->
        {:error, "extract of #{key} failed (exit #{status})"}

      other ->
        other
    end
  end

  defp ensure_bucket(target) do
    target.bucket
    |> S3.put_bucket(region())
    |> request(target)
    |> case do
      {:ok, _} -> :ok
      {:error, {:http_error, 409, _}} -> :ok
      {:error, reason} -> {:error, "could not create target bucket: #{inspect(reason)}"}
    end
  end

  defp upload_tree(dir, target) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.reduce_while(:ok, fn path, _acc ->
      key = Path.relative_to(path, dir)

      path
      |> S3.Upload.stream_file()
      |> S3.upload(target.bucket, key)
      |> request(target)
      |> case do
        {:ok, _} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, "upload of #{key} failed: #{scrub(inspect(reason), target)}"}}
      end
    end)
  end

  # Remote targets pass per-request ExAws overrides (endpoint + creds);
  # local targets use the app's default ExAws config.
  defp request(op, %{ex_aws_overrides: []}), do: @ex_aws.request(op)
  defp request(op, %{ex_aws_overrides: overrides}), do: @ex_aws.request(op, overrides)

  defp region, do: Application.get_env(:ex_aws, :region) || "us-east-1"

  defp scrub(text, target) when is_binary(text) do
    target
    |> target_secrets()
    |> Enum.reduce(text, &String.replace(&2, &1, "[REDACTED]"))
  end

  defp target_secrets(target) do
    pg_password =
      case List.keyfind(target.pg_env, "PGPASSWORD", 0) do
        {"PGPASSWORD", pw} -> pw
        _ -> nil
      end

    s3_secret = Keyword.get(target.ex_aws_overrides, :secret_access_key)

    Enum.reject([pg_password, s3_secret], &(&1 in [nil, ""]))
  end
end
