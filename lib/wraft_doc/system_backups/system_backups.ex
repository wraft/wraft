defmodule WraftDoc.SystemBackups do
  @moduledoc """
  Context for whole-application backups (database dump + bucket mirror).

  Concurrency contract (R6 of the backup plan): at most one backup may be
  `pending` or `running` at any time. The authoritative guard is the
  constant-expression partial unique index `system_backups_single_active_idx`
  — not Oban uniqueness, which dissolves when `Oban.Plugins.Lifeline`
  discards a long-running job at the 5-minute mark. Liveness is owned by
  `heartbeat_at` (refreshed by the worker's timer); `reconcile_stale/0`
  flips only stale-heartbeat `running` rows to `failed` and never reads
  Oban job state.
  """

  import Ecto.Query

  require Logger

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo
  alias WraftDoc.SystemBackups.Backup
  alias WraftDoc.SystemBackups.BackupEngine
  alias WraftDoc.SystemBackups.DownloadToken
  alias WraftDoc.SystemBackups.Event
  alias WraftDoc.SystemBackups.RemoteTarget
  alias WraftDoc.SystemBackups.Restore
  alias WraftDoc.SystemBackups.Schedule
  alias WraftDoc.Workers.SystemBackupImportWorker
  alias WraftDoc.Workers.SystemBackupRetentionWorker
  alias WraftDoc.Workers.SystemBackupWorker
  alias WraftDoc.Workers.SystemRestoreWorker

  # A running row whose heartbeat is older than this is considered orphaned
  # (worker crashed / node died). 10x the worker's 1-minute heartbeat timer.
  @heartbeat_staleness_seconds 60 * 10

  # Restores carry no heartbeat and can legitimately run up to the 6h worker
  # timeout; a running restore older than this (timeout + 1h buffer) is dead.
  @restore_staleness_seconds 60 * 60 * 7

  @error_max_length 2_000

  @doc """
  Minimum seconds between manual backups, from the schedule
  (`manual_cooldown_minutes`). 0 means no limit — the single-in-flight
  index already prevents concurrent backups, so this is optional abuse
  protection. Failed runs never count toward it.
  """
  def manual_cooldown_seconds, do: get_schedule().manual_cooldown_minutes * 60

  def heartbeat_staleness_seconds, do: @heartbeat_staleness_seconds

  @doc "Whether the backup feature is enabled (default OFF)."
  def enabled? do
    Application.get_env(:wraft_doc, :system_backup, [])[:enabled] == true
  end

  @doc "How many completed backups retention keeps (from the schedule, default 7)."
  def retention_count do
    get_schedule().retention_count ||
      Application.get_env(:wraft_doc, :system_backup, [])[:retention_count] || 7
  end

  @doc """
  Admin-triggered backup: inserts the pending row (the index is the
  concurrency guard), then enqueues the worker carrying the row id.
  """
  @spec trigger_manual(InternalUser.t()) ::
          {:ok, Backup.t()} | {:error, :disabled | :backup_in_progress | :cooldown | term()}
  def trigger_manual(%InternalUser{} = admin) do
    with true <- enabled?() || {:error, :disabled},
         {:ok, backup} <- create_pending(:manual, admin) do
      case Oban.insert(SystemBackupWorker.new(%{"backup_id" => backup.id})) do
        {:ok, _job} ->
          {:ok, backup}

        {:error, reason} ->
          # Don't leave a pending row that would wedge the single-in-flight
          # index until reconcile clears it — fail it now.
          mark_failed(backup, "enqueue failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc "Enqueues a retention prune; separate job so its failure never fails a backup."
  def schedule_retention do
    %{} |> SystemBackupRetentionWorker.new() |> Oban.insert()
  end

  @doc """
  Imports an uploaded Full backup tar (already staged at `tar_path`):
  inserts an `:imported` backup row and enqueues the import worker, which
  extracts the parts, uploads them, and marks the row completed.
  """
  def import_backup(%InternalUser{} = admin, tar_path) when is_binary(tar_path) do
    with true <- enabled?() || {:error, :disabled},
         {:ok, backup} <-
           %Backup{}
           |> Backup.changeset(%{trigger_type: :imported, creator_id: admin.id})
           |> Repo.insert() do
      case Oban.insert(
             SystemBackupImportWorker.new(%{"backup_id" => backup.id, "tar_path" => tar_path})
           ) do
        {:ok, _job} ->
          {:ok, backup}

        {:error, reason} ->
          mark_failed(backup, "enqueue failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, %Ecto.Changeset{}} -> {:error, :backup_in_progress}
      other -> other
    end
  end

  @doc "Deletes every object under a backup prefix from the backup bucket."
  defdelegate delete_prefix(prefix), to: BackupEngine

  @doc "Whether an object exists in the backup bucket."
  defdelegate artifact_exists?(key), to: BackupEngine

  @doc "Byte size of a backup-bucket object, or nil."
  defdelegate object_size(key), to: BackupEngine

  @doc "Chunked stream of an object body from the backup bucket."
  defdelegate artifact_stream(key), to: BackupEngine

  @doc "Object key for a backup part (`:db | :bucket | :manifest`)."
  def part_key(%Backup{file_path: prefix}, :db), do: prefix <> "database.dump"
  def part_key(%Backup{file_path: prefix}, :bucket), do: prefix <> "bucket.tar"
  def part_key(%Backup{file_path: prefix}, :manifest), do: prefix <> "manifest.json"

  @doc "Suggested download filename for a part (stamped with the backup's creation time)."
  def part_filename(%Backup{} = backup, :db), do: "#{filename_stem(backup)}-database.dump"
  def part_filename(%Backup{} = backup, :bucket), do: "#{filename_stem(backup)}-bucket.tar"
  def part_filename(%Backup{} = backup, :manifest), do: "#{filename_stem(backup)}-manifest.json"
  def part_filename(%Backup{} = backup, :full), do: "#{filename_stem(backup)}.zip"

  # `wraft-backup-YYYYMMDD-HHMMSS` from the row's creation time (UTC); falls
  # back to the id only if the row somehow has no timestamp.
  defp filename_stem(%Backup{inserted_at: %NaiveDateTime{} = at}),
    do: "wraft-backup-#{Calendar.strftime(at, "%Y%m%d-%H%M%S")}"

  defp filename_stem(%Backup{inserted_at: %DateTime{} = at}),
    do: "wraft-backup-#{Calendar.strftime(at, "%Y%m%d-%H%M%S")}"

  defp filename_stem(%Backup{id: id}), do: "wraft-backup-#{id}"

  @doc "Deletes a backup: removes all its objects, then soft-deletes the row."
  def delete_backup(%Backup{} = backup) do
    case delete_prefix(backup.file_path) do
      :ok -> mark_deleted(backup)
      {:error, reason} -> {:error, reason}
    end
  end

  # ≤60s per the plan: long enough for a redirect round-trip, short
  # enough that a leaked URL is useless almost immediately.
  @download_token_ttl_seconds 60
  @download_parts ~w(db bucket full)

  @doc """
  Mints a single-use download token bound to the admin, backup, and part
  (`"db" | "bucket" | "full"`). Returns the RAW token (only its SHA-256
  hash is stored). Opportunistically purges expired tokens.
  """
  def create_download_token(%InternalUser{} = admin, %Backup{} = backup, part)
      when part in @download_parts do
    Repo.delete_all(from(t in DownloadToken, where: t.expires_at < ^DateTime.utc_now()))

    raw = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@download_token_ttl_seconds, :second)
      |> DateTime.truncate(:second)

    %DownloadToken{}
    |> DownloadToken.changeset(%{
      token_hash: hash_token(raw),
      part: part,
      expires_at: expires_at,
      backup_id: backup.id,
      admin_id: admin.id
    })
    |> Repo.insert()
    |> case do
      {:ok, _token} -> {:ok, raw}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_download_token(_admin, _backup, _part), do: {:error, :invalid_part}

  @doc """
  Atomically consumes a download token for a specific part (delete-on-use;
  reuse, expiry, and part/owner mismatch are all denials).
  """
  def claim_download_token(raw, admin_id, backup_id, part) when is_binary(raw) do
    hash = hash_token(raw)

    query =
      from(t in DownloadToken,
        where:
          t.token_hash == ^hash and t.admin_id == ^admin_id and
            t.backup_id == ^backup_id and t.part == ^part and
            t.expires_at > ^DateTime.utc_now()
      )

    case Repo.delete_all(query) do
      {1, _} -> :ok
      _ -> :error
    end
  end

  def claim_download_token(_raw, _admin_id, _backup_id, _part), do: :error

  defp hash_token(raw),
    do: :sha256 |> :crypto.hash(raw) |> Base.encode16(case: :lower)

  @doc """
  Records a download audit event (mint / allowed / denied) and emits a
  tagged log line so the trail also lands in any external log
  aggregation that survives a database wipe.
  """
  def record_download_event(event, attrs) do
    Logger.warning(
      "[backup_download] event=#{event} backup=#{attrs[:backup_id]} " <>
        "admin=#{attrs[:admin_id]} ip=#{attrs[:ip]} detail=#{attrs[:detail]}"
    )

    %Event{}
    |> Event.changeset(Map.put(attrs, :event, to_string(event)))
    |> Repo.insert()
  end

  @doc """
  Inserts a `pending` backup row. Returns:

    * `{:ok, backup}`
    * `{:error, :backup_in_progress}` — a pending/running backup exists
      (surfaced from the partial-unique-index conflict, so concurrent
      inserts cannot race past an application-level check)
    * `{:error, :cooldown}` — a manual trigger inside the configurable
      `manual_cooldown_minutes` window (default 0 = no limit)
  """
  @spec create_pending(:manual | :scheduled, InternalUser.t() | nil) ::
          {:ok, Backup.t()} | {:error, :backup_in_progress | :cooldown}
  def create_pending(trigger_type, creator \\ nil)

  def create_pending(:manual, creator) do
    if manual_cooldown_active?() do
      {:error, :cooldown}
    else
      insert_pending(:manual, creator)
    end
  end

  def create_pending(:scheduled, _creator), do: insert_pending(:scheduled, nil)

  defp insert_pending(trigger_type, creator) do
    %Backup{}
    |> Backup.changeset(%{trigger_type: trigger_type, creator_id: creator && creator.id})
    |> Repo.insert()
    |> case do
      {:ok, backup} -> {:ok, backup}
      {:error, %Ecto.Changeset{}} -> {:error, :backup_in_progress}
    end
  end

  defp manual_cooldown_active? do
    case manual_cooldown_seconds() do
      seconds when seconds > 0 ->
        cutoff = DateTime.add(DateTime.utc_now(), -seconds, :second)

        Repo.exists?(
          from(b in Backup,
            where:
              b.trigger_type == :manual and b.status != :failed and b.status != :deleted and
                b.inserted_at > ^cutoff
          )
        )

      # 0 = no cooldown; concurrency is still guarded by the unique index.
      _ ->
        false
    end
  end

  @doc "Whether a backup is currently pending or running."
  def in_flight? do
    Repo.exists?(from(b in Backup, where: b.status in [:pending, :running]))
  end

  def get_backup(id) do
    Repo.get(Backup, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  def list_backups(limit \\ 50) do
    Repo.all(
      from(b in Backup,
        order_by: [desc: b.inserted_at],
        limit: ^limit,
        preload: [:creator]
      )
    )
  end

  def mark_running(%Backup{} = backup) do
    now = now()

    backup
    |> Backup.update_changeset(%{status: :running, started_at: now, heartbeat_at: now})
    |> Repo.update()
  end

  @doc "Refreshes the liveness heartbeat; called by the worker's timer."
  def heartbeat(backup_id) do
    {count, _} =
      Repo.update_all(
        from(b in Backup, where: b.id == ^backup_id and b.status == :running),
        set: [heartbeat_at: now()]
      )

    if count == 1, do: :ok, else: :error
  end

  @doc """
  Publishes a finished backup. The `WHERE status = 'running'` makes this
  the atomic publish bit: if the row was meanwhile reconciled to `failed`
  (stale heartbeat), the transition is refused with `{:error, :not_running}`
  and the caller must delete the just-uploaded artifact.
  """
  def mark_completed(%Backup{} = backup, attrs) do
    query = from(b in Backup, where: b.id == ^backup.id and b.status == :running, select: b)

    update =
      Repo.update_all(query,
        set: [
          status: :completed,
          completed_at: now(),
          file_path: attrs[:file_path],
          file_size: attrs[:file_size],
          db_size: attrs[:db_size],
          db_checksum: attrs[:db_checksum],
          bucket_size: attrs[:bucket_size],
          bucket_checksum: attrs[:bucket_checksum],
          manifest: attrs[:manifest] || %{}
        ]
      )

    case update do
      {1, [row]} -> {:ok, row}
      {0, _} -> {:error, :not_running}
    end
  end

  @doc """
  Flips a backup to `failed`. Guarded with `WHERE status IN
  ('pending','running')` so it can never demote an already-`completed`
  row back to `failed` (e.g. if a post-publish step raises) — that would
  orphan a published artifact from row-driven retention.
  """
  def mark_failed(%Backup{} = backup, error) do
    query =
      from(b in Backup,
        where: b.id == ^backup.id and b.status in [:pending, :running],
        select: b
      )

    case Repo.update_all(query,
           set: [status: :failed, error: truncate_error(error), completed_at: now()]
         ) do
      {1, [row]} -> {:ok, row}
      {0, _} -> {:error, :not_in_flight}
    end
  end

  def mark_deleted(%Backup{} = backup) do
    backup
    |> Backup.update_changeset(%{status: :deleted})
    |> Repo.update()
  end

  @doc """
  Reconciles orphaned in-flight rows to `failed` so a crash can never
  wedge the single-in-flight index permanently. Two cases, neither of
  which reads Oban job state:

    * `running` rows whose heartbeat went stale (worker crash / node loss
      after `mark_running`).
    * `pending` rows older than the staleness window that were never
      picked up — e.g. the worker died (or Lifeline discarded the job)
      between `create_pending` and `mark_running`, or `Oban.insert`
      failed after the row was inserted. Pending rows carry no heartbeat,
      so they are bounded by `inserted_at` instead.

  `completed`/`deleted` are terminal and never touched.
  """
  def reconcile_stale do
    cutoff = DateTime.add(DateTime.utc_now(), -@heartbeat_staleness_seconds, :second)

    {count, _} =
      Repo.update_all(
        from(b in Backup,
          where:
            (b.status == :running and b.heartbeat_at < ^cutoff) or
              (b.status == :pending and b.inserted_at < ^cutoff)
        ),
        set: [
          status: :failed,
          error:
            "backup orphaned: never progressed (worker crash, node loss, or enqueue failure)",
          completed_at: now()
        ]
      )

    count
  end

  @doc """
  Completed backups beyond the newest `keep` — retention candidates.
  Counts manual and scheduled in a single pool; never returns
  `running`/`pending` rows.
  """
  def prunable(keep) when is_integer(keep) and keep >= 0 do
    Repo.all(
      from(b in Backup,
        where: b.status == :completed,
        order_by: [desc: b.inserted_at],
        offset: ^keep
      )
    )
  end

  @doc "Count of completed backups — used by retention to decide how many to prune."
  def completed_count do
    Repo.aggregate(from(b in Backup, where: b.status == :completed), :count)
  end

  @doc """
  Starts a restore of a completed backup into a NEW target database and
  bucket (never the live ones). Inserts a `pending` restore row (the
  partial unique index guards single-in-flight) and enqueues the worker.

  Returns `{:ok, restore}`, `{:error, :not_restorable}` (backup not
  completed), or `{:error, :restore_in_progress}`.
  """
  def start_restore(%InternalUser{} = admin, %Backup{status: :completed} = backup) do
    with true <- enabled?() || {:error, :disabled} do
      short = binary_part(backup.id, 0, 8)

      changeset =
        Restore.local_changeset(%Restore{}, %{
          backup_id: backup.id,
          creator_id: admin.id,
          target_database: "wraft_restored_#{short}",
          target_bucket: "wraft-restored-#{short}"
        })

      insert_restore(changeset)
    end
  end

  def start_restore(_admin, _backup), do: {:error, :not_restorable}

  @doc """
  Starts a restore of a completed backup into a target on ANOTHER site.
  `remote` carries `remote_database_url`, `remote_s3_endpoint`,
  `remote_s3_bucket`, `remote_s3_access_key_id`, `remote_s3_secret`.
  """
  def start_remote_restore(%InternalUser{} = admin, %Backup{status: :completed} = backup, remote) do
    with true <- enabled?() || {:error, :disabled},
         true <- RemoteTarget.enabled?() || {:error, :remote_restore_disabled},
         :ok <- RemoteTarget.validate(remote) do
      changeset =
        Restore.remote_changeset(
          %Restore{},
          Map.merge(remote, %{backup_id: backup.id, creator_id: admin.id})
        )

      insert_restore(changeset)
    end
  end

  def start_remote_restore(_admin, _backup, _remote), do: {:error, :not_restorable}

  defp insert_restore(changeset) do
    case Repo.insert(changeset) do
      {:ok, restore} ->
        case Oban.insert(SystemRestoreWorker.new(%{"restore_id" => restore.id})) do
          {:ok, _job} ->
            {:ok, restore}

          {:error, reason} ->
            mark_restore_failed(restore, "enqueue failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :status),
          do: {:error, :restore_in_progress},
          else: {:error, :invalid_remote}
    end
  end

  def get_restore(id) do
    Repo.get(Restore, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  @doc "Most recent restore for a backup (for the UI), or nil."
  def latest_restore_for(backup_id) do
    Repo.one(
      from(r in Restore,
        where: r.backup_id == ^backup_id,
        order_by: [desc: r.inserted_at],
        limit: 1
      )
    )
  end

  @doc """
  Most recent restore per backup id, as a `%{backup_id => Restore}` map.
  One query for the whole history table (avoids an N+1 in the LiveView).
  """
  def latest_restores_for(backup_ids) when is_list(backup_ids) do
    query =
      from(r in Restore,
        where: r.backup_id in ^backup_ids,
        order_by: [asc: r.backup_id, desc: r.inserted_at],
        distinct: r.backup_id
      )

    query |> Repo.all() |> Map.new(&{&1.backup_id, &1})
  end

  @doc "Whether any restore is currently pending or running."
  def restore_in_flight? do
    Repo.exists?(from(r in Restore, where: r.status in [:pending, :running]))
  end

  def mark_restore_running(%Restore{} = restore) do
    restore
    |> Restore.update_changeset(%{status: :running, started_at: now()})
    |> Repo.update()
  end

  def mark_restore_completed(%Restore{} = restore) do
    restore
    |> Restore.update_changeset(%{status: :completed, completed_at: now()})
    |> Repo.update()
  end

  def mark_restore_failed(%Restore{} = restore, error) do
    restore
    |> Restore.update_changeset(%{
      status: :failed,
      error: truncate_error(error),
      completed_at: now()
    })
    |> Repo.update()
  end

  @doc """
  Reconciles orphaned restores to `failed` so a crashed worker (or a
  Lifeline-discarded job, since restores are `max_attempts: 1`) can't wedge
  the single-active restore index permanently. Restores carry no heartbeat,
  so liveness is bounded by `started_at`/`inserted_at`: a `running` restore
  older than the worker timeout (+ buffer) or a `pending` restore older than
  the staleness window is considered dead. Runs from the schedule checker.
  """
  def reconcile_stale_restores do
    running_cutoff = DateTime.add(DateTime.utc_now(), -@restore_staleness_seconds, :second)
    pending_cutoff = DateTime.add(DateTime.utc_now(), -@heartbeat_staleness_seconds, :second)

    query =
      from(r in Restore,
        where:
          (r.status == :running and r.started_at < ^running_cutoff) or
            (r.status == :pending and r.inserted_at < ^pending_cutoff)
      )

    {count, _} =
      Repo.update_all(query,
        set: [
          status: :failed,
          error: "restore orphaned (worker crash or node loss)",
          completed_at: now()
        ]
      )

    count
  end

  @doc "The singleton schedule row, created with defaults on first read."
  def get_schedule do
    Repo.one(from(s in Schedule, limit: 1)) || create_default_schedule()
  end

  # Race-safe: concurrent callers both insert, but the singleton unique index
  # makes all-but-one a no-op (on_conflict: :nothing); then everyone reads the
  # one surviving row.
  defp create_default_schedule do
    Repo.insert(%Schedule{}, on_conflict: :nothing)
    Repo.one!(from(s in Schedule, limit: 1))
  end

  @doc "Updates the schedule (enabled, frequency, hour, minute, day_of_week, retention_count)."
  def update_schedule(attrs) do
    get_schedule()
    |> Schedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  If the schedule is enabled and due `at` (a DateTime), enqueues a
  scheduled backup and stamps `last_run_on` so it runs at most once per
  period. Called by the hourly checker. Returns `:enqueued | :not_due`.
  """
  def maybe_run_scheduled(at \\ DateTime.utc_now()) do
    schedule = get_schedule()

    if schedule_due?(schedule, at) do
      run_scheduled(schedule, DateTime.to_date(at))
    else
      :not_due
    end
  end

  defp run_scheduled(schedule, today) do
    case create_pending(:scheduled) do
      {:ok, backup} ->
        enqueue_scheduled(schedule, backup, today)

      # A backup is already in flight — don't consume the period; the
      # next tick retries once it clears.
      {:error, _} ->
        :not_due
    end
  end

  defp enqueue_scheduled(schedule, backup, today) do
    case Oban.insert(SystemBackupWorker.new(%{"backup_id" => backup.id})) do
      {:ok, _job} ->
        # Stamp only after a backup is actually enqueued, so a manual
        # backup in flight at the scheduled time doesn't consume the
        # period and silently skip the day's scheduled run.
        schedule |> Schedule.run_changeset(today) |> Repo.update()
        :enqueued

      {:error, reason} ->
        # Enqueue failed: release the pending row so it doesn't wedge the
        # single-active index, and don't consume the period (next tick
        # retries). Mirrors trigger_manual/1's enqueue-failure handling.
        mark_failed(backup, "enqueue failed: #{inspect(reason)}")
        :not_due
    end
  end

  defp schedule_due?(%Schedule{enabled: false}, _at), do: false

  defp schedule_due?(%Schedule{} = s, at) do
    today = DateTime.to_date(at)
    time_reached? = at.hour > s.hour or (at.hour == s.hour and at.minute >= s.minute)
    not_run_today? = s.last_run_on != today
    day_matches? = s.frequency == :daily or Date.day_of_week(today) == s.day_of_week

    enabled_and_configured?(s) and time_reached? and not_run_today? and day_matches?
  end

  defp enabled_and_configured?(%Schedule{enabled: true}), do: enabled?()
  defp enabled_and_configured?(_), do: false

  defp truncate_error(nil), do: nil

  defp truncate_error(error) when is_binary(error),
    do: String.slice(error, 0, @error_max_length)

  defp truncate_error(error), do: error |> inspect() |> String.slice(0, @error_max_length)

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)
end
