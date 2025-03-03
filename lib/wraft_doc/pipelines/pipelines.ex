defmodule WraftDoc.Pipelines do
  @moduledoc """
  The pipelines context.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Forms
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.Stages
  alias WraftDoc.Repo

  @doc """
  Create a pipeline.
  """
  @spec create_pipeline(User.t(), map) :: Pipeline.t() | {:error, Ecto.Changeset.t()}
  def create_pipeline(%{current_org_id: org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)

    current_user
    |> build_assoc(:pipelines)
    |> Pipeline.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, pipeline} ->
        Stages.create_pipe_stages(current_user, pipeline, params)

        Repo.preload(pipeline,
          stages: [
            [content_type: [{:fields, :field_type}]],
            :data_template,
            :state,
            :form_mapping
          ]
        )

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  List of all pipelines in the user's organisation.
  """
  @spec pipeline_index(User.t(), map) :: map | nil
  def pipeline_index(%User{current_org_id: org_id}, params) do
    Pipeline
    |> where([p], p.organisation_id == ^org_id)
    |> where(^pipeline_filter_by_name(params))
    |> order_by(^pipeline_sort(params))
    |> join(:left, [p], ps in assoc(p, :stages))
    |> select_merge([p, ps], %{stages_count: count(ps.id)})
    |> group_by([p], p.id)
    |> Repo.paginate(params)
  end

  def pipeline_index(_, _), do: nil

  defp pipeline_filter_by_name(%{"name" => name} = _params),
    do: dynamic([p], ilike(p.name, ^"%#{name}%"))

  defp pipeline_filter_by_name(_), do: true

  defp pipeline_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([p], p.name)]

  defp pipeline_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([p], p.name)]

  defp pipeline_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([p], p.inserted_at)]

  defp pipeline_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([p], p.inserted_at)]

  defp pipeline_sort(_), do: []

  @doc """
  Get a pipeline from its UUID and user's organisation.
  """
  @spec get_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def get_pipeline(%User{current_org_id: org_id}, <<_::288>> = p_uuid) do
    query = from(p in Pipeline, where: p.id == ^p_uuid, where: p.organisation_id == ^org_id)
    Repo.one(query)
  end

  def get_pipeline(_, _), do: nil

  @doc """
  Get a pipeline and its details.
  """
  @spec show_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def show_pipeline(current_user, p_uuid) do
    current_user
    |> get_pipeline(p_uuid)
    |> Repo.preload([
      :creator,
      stages: [[content_type: [{:fields, :field_type}]], :data_template, :state, :form_mapping]
    ])
  end

  @doc """
  Updates a pipeline.
  """
  @spec pipeline_update(Pipeline.t(), User.t(), map) :: Pipeline.t()
  def pipeline_update(%Pipeline{} = pipeline, %User{} = user, params) do
    pipeline
    |> Pipeline.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, pipeline} ->
        Stages.create_pipe_stages(user, pipeline, params)

        Repo.preload(pipeline, [
          :creator,
          stages: [
            [content_type: [{:fields, :field_type}]],
            :data_template,
            :state,
            :form_mapping
          ]
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  def pipeline_update(_, _, _), do: nil

  @doc """
  Delete a pipeline.
  """
  @spec delete_pipeline(Pipeline.t()) :: {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()} | nil
  def delete_pipeline(%Pipeline{} = pipeline) do
    Forms.delete_form_pipeline(pipeline)
    Repo.delete(pipeline)
  end

  def delete_pipeline(_), do: nil
end
