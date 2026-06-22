defmodule WraftDoc.BackupStubs do
  @moduledoc """
  Shared Mox stubs for backup-engine collaborators: happy-path shell-outs
  (df/pg_dump/pg_restore/tar via `CmdRunnerMock`) and S3 traffic
  (list/download/upload/head via `ExAwsMock`). Individual tests override
  specific calls with `Mox.expect/4` — expectations are consumed before
  stubs.

  The engine produces three plaintext parts (database.dump, bucket.tar,
  manifest.json) and verifies each upload via head_object size. To make
  those verifies pass, the shell stubs write fixed-size files and the head
  stub reports matching sizes keyed off the object suffix.
  """

  import ExUnit.Assertions
  import Mox

  # Fixed part contents so head_object can echo matching sizes.
  @dump_content String.duplicate("d", 2_048)
  @tar_content "BUCKETTARBYTES"

  def dump_size, do: byte_size(@dump_content)
  def tar_size, do: byte_size(@tar_content)

  @doc """
  Sets `:system_backup` app config for a test (restored on exit).
  Defaults to a fully enabled feature against the test backup bucket.
  """
  def put_backup_config(overrides \\ []) do
    original = Application.get_env(:wraft_doc, :system_backup)

    config =
      Keyword.merge(
        [
          enabled: true,
          backup_bucket: "wraft-backups-test",
          retention_count: 7,
          cloak_key_label: "v1",
          min_free_disk_bytes: 1_024,
          # Remote restore is off by default in prod; tests enable it and skip
          # host resolution via the `:any` allowlist (live-target guard still
          # runs against the test DB/bucket).
          remote_restore_enabled: true,
          remote_allowed_hosts: :any
        ],
        overrides
      )

    Application.put_env(:wraft_doc, :system_backup, config)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:wraft_doc, :system_backup, original)
    end)

    config
  end

  @doc "Happy-path stubs for every shell-out the engine makes (no age)."
  def stub_cmds(_opts \\ []) do
    stub(CmdRunnerMock, :cmd, fn
      "df", _args, _opts ->
        {"Filesystem 1K-blocks Used Available Capacity Mounted\n/dev/x 1 1 999999999 1% /", 0}

      "pg_dump", ["--version"], _opts ->
        {"pg_dump (PostgreSQL) 15.12", 0}

      "pg_dump", args, cmd_opts ->
        refute Enum.any?(args, &String.contains?(&1, "postgres://"))
        assert {"PGDATABASE", _} = List.keyfind(cmd_opts[:env], "PGDATABASE", 0)

        dump_path = args |> Enum.drop_while(&(&1 != "-f")) |> Enum.at(1)
        File.write!(dump_path, @dump_content)
        {"", 0}

      "pg_restore", ["--list", _path], _opts ->
        {"; archive listing", 0}

      "tar", args, _opts ->
        tar_path = args |> Enum.drop_while(&(&1 != "-cf")) |> Enum.at(1)
        File.write!(tar_path, @tar_content)
        {"", 0}
    end)
  end

  @doc """
  Happy-path S3 stubs for a backup build: list app-bucket objects, mirror
  each, accept per-part uploads, and report matching head_object sizes.
  """
  def stub_s3(object_keys, opts \\ []) do
    download_result = Keyword.get(opts, :download_result, fn _key -> {:ok, :done} end)

    stub(ExAwsMock, :stream!, fn %ExAws.Operation.S3{} = _list_op ->
      Enum.map(object_keys, &%{key: &1})
    end)

    stub(ExAwsMock, :request, fn
      %ExAws.S3.Download{path: key} ->
        download_result.(key)

      %ExAws.S3.Upload{} ->
        {:ok, %{}}

      %ExAws.Operation.S3{http_method: :head, path: path} ->
        {:ok, %{headers: [{"Content-Length", to_string(head_size(path))}]}}

      %ExAws.Operation.S3{http_method: :delete} ->
        {:ok, %{}}
    end)
  end

  defp head_size(path) do
    cond do
      String.ends_with?(path, "database.dump") -> dump_size()
      String.ends_with?(path, "bucket.tar") -> tar_size()
      true -> 0
    end
  end
end
