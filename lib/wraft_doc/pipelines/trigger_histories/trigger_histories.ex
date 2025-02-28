defmodule WraftDoc.Pipelines.TriggerHistories do
  @moduledoc """
  The trigger histories context.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Document
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo

  @doc """
  Creates a pipeline trigger history with a user association.

  ## Example
  iex> create_trigger_history(%User{}, %Pipeline{}, %{name: "John Doe"})
  {:ok, %TriggerHistory{}}

  iex> create_trigger_history(%User{}, %Pipeline{}, "meta")
  {:error, Ecto.Changeset}

  iex> create_trigger_history("user", "pipeline", "meta")
  nil
  """
  @spec create_trigger_history(User.t(), Pipeline.t(), map) ::
          {:ok, TriggerHistory.t()} | {:error, Ecto.Changeset.t()} | nil
  def create_trigger_history(%User{id: u_id}, %Pipeline{} = pipeline, data) do
    state = TriggerHistory.states()[:enqued]

    pipeline
    |> build_assoc(:trigger_histories, creator_id: u_id)
    |> TriggerHistory.changeset(%{data: data, state: state})
    |> Repo.insert()
  end

  def create_trigger_history(_, _, _), do: nil

  @doc """
  Get all the triggers under a pipeline.
  """
  @spec get_trigger_histories_of_a_pipeline(Pipeline.t(), map) :: Scrivener.Page.t()
  def get_trigger_histories_of_a_pipeline(%Pipeline{id: id}, params) do
    query =
      from(t in TriggerHistory,
        where: t.pipeline_id == ^id,
        preload: [:creator],
        order_by: [desc: t.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def get_trigger_histories_of_a_pipeline(_, _), do: nil

  @doc """
  Get all the triggers under a organisation.
  """
  @spec trigger_history_index(User.t(), map) :: Scrivener.Page.t()
  def trigger_history_index(%User{current_org_id: org_id} = _user, params) do
    TriggerHistory
    |> join(:inner, [t], p in Pipeline, on: t.pipeline_id == p.id, as: :pipeline)
    |> where([pipeline: p], p.organisation_id == ^org_id)
    |> where(^trigger_history_filter_by_pipeline_name(params))
    |> where(^trigger_history_filter_by_status(params))
    |> order_by(^trigger_history_sort(params))
    |> preload([:creator])
    |> Repo.paginate(params)
  end

  def trigger_history_index(_, _), do: nil

  defp trigger_history_filter_by_pipeline_name(%{"pipeline_name" => pipeline_name} = _params),
    do: dynamic([pipeline: p], ilike(p.name, ^"%#{pipeline_name}%"))

  defp trigger_history_filter_by_pipeline_name(_), do: true

  defp trigger_history_filter_by_status(%{"status" => status} = _params),
    do: dynamic([t], t.state == ^status)

  defp trigger_history_filter_by_status(_), do: true

  defp trigger_history_sort(%{"sort" => "pipeline_name"} = _params),
    do: [asc: dynamic([pipeline: p], p.name)]

  defp trigger_history_sort(%{"sort" => "pipeline_name_desc"} = _params),
    do: [desc: dynamic([pipeline: p], p.name)]

  defp trigger_history_sort(%{"sort" => "status"} = _params), do: [asc: dynamic([t], t.state)]

  defp trigger_history_sort(%{"sort" => "status_desc"} = _params),
    do: [desc: dynamic([t], t.state)]

  defp trigger_history_sort(%{"sort" => "inserted_at"} = _params),
    do: [asc: dynamic([t], t.inserted_at)]

  defp trigger_history_sort(%{"sort" => "inserted_at_desc"} = _params),
    do: [desc: dynamic([t], t.inserted_at)]

  defp trigger_history_sort(_), do: []

  @doc """
  Creates a background job to run a pipeline.
  """
  # TODO - improve tests
  @spec create_pipeline_job(TriggerHistory.t(), DateTime.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def create_pipeline_job(%TriggerHistory{} = trigger_history, scheduled_at) do
    Document.create_bulk_job(trigger_history, scheduled_at, ["pipeline_job"])
  end

  def create_pipeline_job(%TriggerHistory{} = trigger_history) do
    Document.create_bulk_job(trigger_history, nil, ["pipeline_job"])
  end

  def create_pipeline_job(_), do: nil
end
