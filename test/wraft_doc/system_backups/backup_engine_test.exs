defmodule WraftDoc.SystemBackups.BackupEngineTest do
  use WraftDoc.DataCase, async: false

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups.BackupEngine

  setup :verify_on_exit!

  setup do
    put_backup_config()
    backup = insert(:system_backup, status: :running, trigger_type: :manual)
    {:ok, backup: backup}
  end

  describe "build/1 happy path" do
    test "produces, uploads, and verifies the separate plaintext parts", %{backup: backup} do
      stub_cmds()
      stub_s3(["organisations/org1/file.pdf", "users/u1/sig.png", "organisations/"])

      assert {:ok, result} = BackupEngine.build(backup)

      assert result.file_path == "system/backups/#{backup.id}/"
      assert result.db_size == dump_size()
      assert result.bucket_size == tar_size()
      assert result.file_size == dump_size() + tar_size()
      assert is_binary(result.db_checksum)
      assert is_binary(result.bucket_checksum)

      # Folder markers are not objects.
      assert result.manifest["object_count"] == 2
      assert result.manifest["skipped_count"] == 0
      assert result.manifest["versions"]["pg_dump"] =~ "15.12"
      assert result.manifest["encryption_scheme"] == "none"
    end

    test "a missing object is skipped and recorded, not fatal", %{backup: backup} do
      stub_cmds()

      stub_s3(["organisations/org1/exists.pdf", "organisations/org1/missing.pdf"],
        download_result: fn
          "organisations/org1/missing.pdf" -> {:error, :not_found}
          _key -> {:ok, :done}
        end
      )

      assert {:ok, result} = BackupEngine.build(backup)
      assert result.manifest["object_count"] == 1
      assert result.manifest["skipped_count"] == 1
      assert result.manifest["skipped_objects"] == ["organisations/org1/missing.pdf"]
    end

    test "a path-escaping object key is skipped, not written outside staging", %{backup: backup} do
      stub_cmds()
      stub_s3(["organisations/org1/file.pdf", "../../../../tmp/evil.sh"])

      assert {:ok, result} = BackupEngine.build(backup)
      assert result.manifest["object_count"] == 1
      assert result.manifest["skipped_count"] == 1
      assert result.manifest["skipped_objects"] == ["../../../../tmp/evil.sh"]
    end

    test "same-bucket fallback excludes prior backups and tmp keys", %{backup: backup} do
      app_bucket = System.get_env("MINIO_BUCKET")

      Application.put_env(
        :wraft_doc,
        :system_backup,
        Keyword.put(Application.get_env(:wraft_doc, :system_backup), :backup_bucket, app_bucket)
      )

      stub_cmds()

      stub_s3([
        "organisations/org1/file.pdf",
        "system/backups/older/database.dump",
        "staging/upload.tmp"
      ])

      assert {:ok, result} = BackupEngine.build(backup)
      assert result.manifest["object_count"] == 1
    end
  end

  describe "build/1 failure paths" do
    test "refuses to run without a backup bucket", %{backup: backup} do
      Application.put_env(
        :wraft_doc,
        :system_backup,
        Keyword.delete(Application.get_env(:wraft_doc, :system_backup), :backup_bucket)
      )

      assert {:error, error} = BackupEngine.build(backup)
      assert error =~ "no backup bucket configured"
    end

    test "fails cleanly on insufficient staging disk", %{backup: backup} do
      stub_cmds()

      expect(CmdRunnerMock, :cmd, fn "df", _args, _opts ->
        {"Filesystem 1K-blocks Used Available Capacity Mounted\n/dev/x 1000 1000 0 100% /", 0}
      end)

      assert {:error, error} = BackupEngine.build(backup)
      assert error =~ "insufficient disk"
    end

    test "pg_dump failure is scrubbed and nothing is uploaded", %{backup: backup} do
      database_url = System.get_env("DATABASE_URL")
      stub_cmds()

      expect(CmdRunnerMock, :cmd, 2, fn
        "df", _args, _opts ->
          {"Filesystem 1K-blocks Used Available Capacity Mounted\n/dev/x 1 1 999999999 1% /", 0}

        "pg_dump", _args, _opts ->
          {"connection to #{database_url} failed: fe_sendauth", 1}
      end)

      assert {:error, error} = BackupEngine.build(backup)
      assert error =~ "pg_dump failed"
      assert error =~ "[REDACTED]"
      refute error =~ database_url
    end

    test "a truncated dump is rejected before packaging", %{backup: backup} do
      stub_cmds()

      expect(CmdRunnerMock, :cmd, 2, fn
        "df", _args, _opts ->
          {"Filesystem 1K-blocks Used Available Capacity Mounted\n/dev/x 1 1 999999999 1% /", 0}

        "pg_dump", args, _opts ->
          dump_path = args |> Enum.drop_while(&(&1 != "-f")) |> Enum.at(1)
          File.write!(dump_path, "tiny")
          {"", 0}
      end)

      assert {:error, error} = BackupEngine.build(backup)
      assert error =~ "suspiciously small"
    end

    test "upload verify size mismatch fails the run", %{backup: backup} do
      stub_cmds()

      stub(ExAwsMock, :stream!, fn _op -> [%{key: "organisations/org1/file.pdf"}] end)

      stub(ExAwsMock, :request, fn
        %ExAws.S3.Download{} -> {:ok, :done}
        %ExAws.S3.Upload{} -> {:ok, %{}}
        # Wrong size for every part.
        %ExAws.Operation.S3{http_method: :head} -> {:ok, %{headers: [{"Content-Length", "1"}]}}
      end)

      assert {:error, error} = BackupEngine.build(backup)
      assert error =~ "size mismatch"
    end
  end
end
