defmodule WraftDoc.Workers.SystemBackupRetentionWorkerTest do
  use WraftDoc.DataCase, async: false

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.Workers.SystemBackupRetentionWorker

  setup :verify_on_exit!

  setup do
    put_backup_config()
    :ok
  end

  defp insert_completed(count, offset_start \\ 0) do
    for i <- (offset_start + 1)..(offset_start + count) do
      insert(:system_backup,
        status: :completed,
        inserted_at: DateTime.add(DateTime.utc_now(), -i * 60, :second)
      )
    end
  end

  # Deletion is prefix-based: list the prefix, delete each key. Stub the
  # listing to return one part-key per prefix so each prune = one delete.
  defp stub_prefix_listing do
    stub(ExAwsMock, :stream!, fn %ExAws.Operation.S3{params: params} ->
      prefix = params["prefix"] || ""
      [%{key: prefix <> "database.dump"}]
    end)
  end

  test "prunes the oldest completed backups beyond the newest N" do
    backups = insert_completed(9)
    [oldest, second_oldest] = backups |> Enum.reverse() |> Enum.take(2)
    test_pid = self()
    stub_prefix_listing()

    expect(ExAwsMock, :request, 2, fn %ExAws.Operation.S3{http_method: :delete, path: path} ->
      send(test_pid, {:deleted, path})
      {:ok, %{}}
    end)

    assert {:ok, %{pruned: 2}} = perform_job(SystemBackupRetentionWorker, %{})

    assert_received {:deleted, path_a}
    assert_received {:deleted, path_b}
    deleted = Enum.sort([path_a, path_b])
    assert Enum.any?(deleted, &String.contains?(&1, oldest.file_path))
    assert Enum.any?(deleted, &String.contains?(&1, second_oldest.file_path))

    assert SystemBackups.get_backup(oldest.id).status == :deleted
    assert SystemBackups.get_backup(second_oldest.id).status == :deleted
    assert SystemBackups.completed_count() == 7
  end

  test "no-op when at or below the retention count" do
    insert_completed(7)

    assert {:ok, %{pruned: 0}} = perform_job(SystemBackupRetentionWorker, %{})
    assert SystemBackups.completed_count() == 7
  end

  test "never touches pending or running rows" do
    {:ok, pending} = SystemBackups.create_pending(:scheduled)
    insert_completed(8, 1)
    stub_prefix_listing()

    expect(ExAwsMock, :request, 1, fn %ExAws.Operation.S3{http_method: :delete} ->
      {:ok, %{}}
    end)

    assert {:ok, %{pruned: 1}} = perform_job(SystemBackupRetentionWorker, %{})
    assert SystemBackups.get_backup(pending.id).status == :pending
  end

  test "one delete failure doesn't abort pruning the rest, and the row stays completed" do
    backups = insert_completed(9)
    [oldest, second_oldest] = backups |> Enum.reverse() |> Enum.take(2)
    stub_prefix_listing()

    expect(ExAwsMock, :request, 2, fn %ExAws.Operation.S3{http_method: :delete, path: path} ->
      if String.contains?(path, second_oldest.file_path) do
        {:error, :service_unavailable}
      else
        {:ok, %{}}
      end
    end)

    assert {:ok, %{pruned: 2}} = perform_job(SystemBackupRetentionWorker, %{})

    assert SystemBackups.get_backup(oldest.id).status == :deleted
    # Failed delete leaves the row completed so a later run retries.
    assert SystemBackups.get_backup(second_oldest.id).status == :completed
  end
end
