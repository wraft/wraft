defmodule WraftDoc.Pipelines.Stages do
  @moduledoc """
    The pipe stages context.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.Stages.Stage
  alias WraftDoc.Repo

  # Create pipe stages by iterating over the list of content type UUIDs
  # given among the params.
  @spec create_pipe_stages(User.t(), Pipeline.t(), map) :: list
  def create_pipe_stages(user, pipeline, %{"stages" => stage_data}) when is_list(stage_data) do
    Enum.map(stage_data, fn stage_params -> create_pipe_stage(user, pipeline, stage_params) end)
  end

  def create_pipe_stages(_, _, _), do: []

  @doc """
  Create a pipe stage.
  """
  # TOOD update the tests as state id is removed from the params.
  @spec create_pipe_stage(User.t(), Pipeline.t(), map) ::
          nil | {:error, Ecto.Changeset.t()} | {:ok, any}
  def create_pipe_stage(
        user,
        pipeline,
        %{
          "content_type_id" => <<_::288>>,
          "data_template_id" => <<_::288>>
        } = params
      ) do
    params
    |> get_pipe_stage_params(user)
    |> do_create_pipe_stages(pipeline)
  end

  def create_pipe_stage(_, _, _), do: nil

  # Get the values for pipe stage creation to create a pipe stage.
  # TODO update tests as state id is removed from the params.
  @spec get_pipe_stage_params(map, User.t()) ::
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()}
  defp get_pipe_stage_params(
         %{
           "content_type_id" => c_type_uuid,
           "data_template_id" => d_temp_uuid
         },
         user
       ) do
    c_type = ContentTypes.get_content_type(user, c_type_uuid)
    d_temp = DataTemplates.get_data_template(user, d_temp_uuid)
    {c_type, d_temp, user}
  end

  defp get_pipe_stage_params(_, _), do: nil

  # Create pipe stages
  # TODO update tests as state id is removed from the params.
  @spec do_create_pipe_stages(
          {ContentType.t(), DataTemplate.t(), User.t()} | nil,
          Pipeline.t()
        ) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_create_pipe_stages(
         {%ContentType{id: c_id}, %DataTemplate{id: d_id}, %User{id: u_id}},
         pipeline
       ) do
    pipeline
    |> build_assoc(:stages,
      content_type_id: c_id,
      data_template_id: d_id,
      creator_id: u_id
    )
    |> Stage.changeset()
    |> Repo.insert()
  end

  defp do_create_pipe_stages(_, _), do: nil

  @doc """
  Get a pipeline stage from its UUID and user's organisation.
  """
  @spec get_pipe_stage(User.t(), Ecto.UUID.t()) :: Stage.t() | nil
  def get_pipe_stage(%User{current_org_id: org_id}, <<_::288>> = s_uuid) do
    query =
      from(s in Stage,
        join: p in Pipeline,
        on: p.organisation_id == ^org_id and s.pipeline_id == p.id,
        where: s.id == ^s_uuid
      )

    Repo.one(query)
  end

  def get_pipe_stage(_, _), do: nil

  @doc """
  Get all required fields and then update a stage.
  """
  @spec update_pipe_stage(User.t(), Stage.t(), map) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  def update_pipe_stage(%User{} = current_user, %Stage{} = stage, %{
        "content_type_id" => c_uuid,
        "data_template_id" => d_uuid
      }) do
    c_type = ContentTypes.get_content_type(current_user, c_uuid)
    d_temp = DataTemplates.get_data_template(current_user, d_uuid)

    do_update_pipe_stage(stage, c_type, d_temp)
  end

  def update_pipe_stage(_, _, _), do: nil

  # Update a stage.
  @spec do_update_pipe_stage(Stage.t(), ContentType.t(), DataTemplate.t()) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_update_pipe_stage(stage, %ContentType{id: c_id}, %DataTemplate{id: d_id}) do
    stage
    |> Stage.update_changeset(%{content_type_id: c_id, data_template_id: d_id})
    |> Repo.update()
  end

  defp do_update_pipe_stage(_, _, _), do: nil

  @doc """
  Deletes a pipe stage.
  """
  @spec delete_pipe_stage(Stage.t()) :: {:ok, Stage.t()} | nil
  def delete_pipe_stage(%Stage{} = pipe_stage), do: Repo.delete(pipe_stage)

  def delete_pipe_stage(_), do: nil

  @doc """
  Preload all datas of a pipe stage excluding pipeline.
  """
  @spec preload_stage_details(Stage.t()) :: Stage.t()
  def preload_stage_details(stage) do
    Repo.preload(stage, [
      {:content_type, fields: [:field_type]},
      :data_template,
      :state,
      :form_mapping
    ])
  end
end
