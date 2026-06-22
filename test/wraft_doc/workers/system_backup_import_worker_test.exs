defmodule WraftDoc.Workers.SystemBackupImportWorkerTest do
  use WraftDoc.DataCase, async: false

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Backup
  alias WraftDoc.Workers.SystemBackupImportWorker

  setup :verify_on_exit!

  setup do
    put_backup_config(enabled: true)
    # The worker extracts the uploaded archive via the @cmd_runner seam;
    # delegate "tar"/"unzip" to the real binaries so extraction happens in tests.
    stub(CmdRunnerMock, :cmd, fn cmd, args, opts when cmd in ["tar", "unzip"] ->
      System.cmd(cmd, args, opts)
    end)

    :ok
  end

  # Builds a real Full backup tar (database.dump + public.tar + private.tar
  # + manifest.json) at a temp path and returns it.
  defp build_full_tar do
    dir = Briefly.create!(directory: true)
    File.write!(Path.join(dir, "database.dump"), "DUMPDATA")
    File.write!(Path.join(dir, "bucket.tar"), "BUCKETDATA")
    File.write!(Path.join(dir, "manifest.json"), "{}")

    tar = Path.join(System.tmp_dir!(), "import-#{System.unique_integer([:positive])}.tar")
    {_, 0} = System.cmd("tar", ["-cf", tar, "-C", dir, "."])
    tar
  end

  # Builds a real Full backup zip (the current format) via the same ZipStream
  # the download uses, exercising the worker's zip-detection + unzip path.
  defp build_full_zip do
    entries = [
      %{name: "database.dump", size: 8, stream: ["DUMPDATA"]},
      %{name: "bucket.tar", size: 10, stream: ["BUCKETDATA"]},
      %{name: "manifest.json", size: 2, stream: ["{}"]}
    ]

    bin =
      entries
      |> WraftDoc.SystemBackups.ZipStream.stream()
      |> Enum.to_list()
      |> IO.iodata_to_binary()

    zip = Path.join(System.tmp_dir!(), "import-#{System.unique_integer([:positive])}.zip")
    File.write!(zip, bin)
    zip
  end

  test "imports an uploaded Full tar and registers a completed backup" do
    admin = insert(:internal_user)
    {:ok, backup} = SystemBackups.import_backup(admin, build_full_tar())
    assert backup.trigger_type == :imported

    test_pid = self()

    # Each part is uploaded to the new backup prefix; head verifies size.
    stub(ExAwsMock, :request, fn
      %ExAws.S3.Upload{path: path} ->
        send(test_pid, {:uploaded, path})
        {:ok, %{}}

      %ExAws.Operation.S3{http_method: :head, path: path} ->
        size =
          cond do
            String.ends_with?(path, "database.dump") -> byte_size("DUMPDATA")
            String.ends_with?(path, "bucket.tar") -> byte_size("BUCKETDATA")
            true -> 2
          end

        {:ok, %{headers: [{"Content-Length", to_string(size)}]}}
    end)

    assert {:ok, :imported} =
             perform_job(SystemBackupImportWorker, %{
               "backup_id" => backup.id,
               "tar_path" => build_full_tar()
             })

    fresh = SystemBackups.get_backup(backup.id)
    assert fresh.status == :completed
    assert fresh.db_size == byte_size("DUMPDATA")
    assert fresh.bucket_size == byte_size("BUCKETDATA")
    assert fresh.file_path == "system/backups/#{backup.id}/"

    # All three parts uploaded under the prefix.
    for name <- ~w(database.dump bucket.tar manifest.json) do
      assert_received {:uploaded, "system/backups/" <> _rest = key}
      assert is_binary(key) and is_binary(name)
    end
  end

  test "imports an uploaded Full zip and registers a completed backup" do
    admin = insert(:internal_user)
    {:ok, backup} = SystemBackups.import_backup(admin, build_full_zip())
    assert backup.trigger_type == :imported

    stub(ExAwsMock, :request, fn
      %ExAws.S3.Upload{} ->
        {:ok, %{}}

      %ExAws.Operation.S3{http_method: :head, path: path} ->
        size =
          cond do
            String.ends_with?(path, "database.dump") -> byte_size("DUMPDATA")
            String.ends_with?(path, "bucket.tar") -> byte_size("BUCKETDATA")
            true -> 2
          end

        {:ok, %{headers: [{"Content-Length", to_string(size)}]}}
    end)

    assert {:ok, :imported} =
             perform_job(SystemBackupImportWorker, %{
               "backup_id" => backup.id,
               "tar_path" => build_full_zip()
             })

    fresh = SystemBackups.get_backup(backup.id)
    assert fresh.status == :completed
    assert fresh.db_size == byte_size("DUMPDATA")
    assert fresh.bucket_size == byte_size("BUCKETDATA")
  end

  test "import fails when the archive lacks database.dump" do
    admin = insert(:internal_user)

    dir = Briefly.create!(directory: true)
    File.write!(Path.join(dir, "public.tar"), "PUB")
    bad_tar = Path.join(System.tmp_dir!(), "bad-#{System.unique_integer([:positive])}.tar")
    {_, 0} = System.cmd("tar", ["-cf", bad_tar, "-C", dir, "."])

    {:ok, backup} = SystemBackups.import_backup(admin, bad_tar)

    assert {:error, _} =
             perform_job(SystemBackupImportWorker, %{
               "backup_id" => backup.id,
               "tar_path" => bad_tar
             })

    assert SystemBackups.get_backup(backup.id).status == :failed
  end

  test "import refuses a tar whose members escape the staging dir (tar-slip)" do
    admin = insert(:internal_user)

    victim = Path.join(System.tmp_dir!(), "tarslip-#{System.unique_integer([:positive])}.txt")
    File.write!(victim, "x")
    evil = Path.join(System.tmp_dir!(), "evil-#{System.unique_integer([:positive])}.tar")
    # -P keeps the leading "/", so the archived member path is absolute.
    {_, 0} = System.cmd("tar", ["-cPf", evil, victim])

    {:ok, backup} = SystemBackups.import_backup(admin, evil)

    assert {:error, _} =
             perform_job(SystemBackupImportWorker, %{
               "backup_id" => backup.id,
               "tar_path" => evil
             })

    assert SystemBackups.get_backup(backup.id).status == :failed
  end

  test "import_backup refuses when the feature is disabled" do
    Application.put_env(
      :wraft_doc,
      :system_backup,
      Keyword.put(Application.get_env(:wraft_doc, :system_backup), :enabled, false)
    )

    assert {:error, :disabled} = SystemBackups.import_backup(insert(:internal_user), "/tmp/x.tar")
    assert Repo.aggregate(Backup, :count) == 0
  end
end
