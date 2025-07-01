defmodule WraftDoc.Storage.SyncJob do
  @moduledoc """
  The sync job model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storage_sync_jobs" do
    field(:status, :string)
    field(:started_at, :utc_datetime)
    field(:job_type, :string)
    field(:sync_source, :string)
    field(:completed_at, :utc_datetime)
    field(:items_processed, :integer)
    field(:items_failed, :integer)
    field(:error_details, :map)
    field(:repository_id, :binary_id)
    field(:triggered_by_id, :binary_id)

    timestamps()
  end

  @doc false
  def changeset(sync_job, attrs) do
    sync_job
    |> cast(attrs, [
      :job_type,
      :sync_source,
      :status,
      :started_at,
      :completed_at,
      :items_processed,
      :items_failed,
      :error_details
    ])
    |> validate_required([
      :job_type,
      :sync_source,
      :status,
      :started_at,
      :completed_at,
      :items_processed,
      :items_failed
    ])
  end
end
