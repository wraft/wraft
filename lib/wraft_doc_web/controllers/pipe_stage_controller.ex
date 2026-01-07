defmodule WraftDocWeb.Api.V1.PipeStageController do
  @moduledoc """
  PipeStageController module handles all the actions associated with
  Pipe stage model.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "pipeline:manage",
    update: "pipeline:manage",
    delete: "pipeline:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Pipelines
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.Stages
  alias WraftDoc.Pipelines.Stages.Stage

  tags(["Pipe Stages"])

  @doc """
  Creates a pipe stage
  """
  operation(:create,
    summary: "Create a pipe stage",
    description: "Create a new pipe stage in a pipeline",
    parameters: [
      pipeline_id: [in: :path, type: :string, description: "ID of the pipeline", required: true]
    ],
    request_body:
      {"Pipe stage to be created", "application/json", Schemas.PipeStage.PipeStageRequestMap},
    responses: [
      ok: {"Ok", "application/json", Schemas.PipeStage.PipeStage},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"pipeline_id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.get_pipeline(current_user, p_uuid),
         {:ok, %Stage{} = stage} <- Stages.create_pipe_stage(current_user, pipeline, params),
         %Stage{} = stage <- Stages.preload_stage_details(stage) do
      render(conn, "stage.json", stage: stage)
    end
  end

  @doc """
  Updates a pipe stage
  """
  operation(:update,
    summary: "Update a pipe stage",
    description: "Update an existing pipe stage",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the pipe stage", required: true]
    ],
    request_body:
      {"Pipe stage to be updated", "application/json", Schemas.PipeStage.PipeStageRequestMap},
    responses: [
      ok: {"Ok", "application/json", Schemas.PipeStage.PipeStage},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => s_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Stage{} = stage <- Stages.get_pipe_stage(current_user, s_uuid),
         {:ok, %Stage{} = stage} <- Stages.update_pipe_stage(current_user, stage, params),
         %Stage{} = stage <- Stages.preload_stage_details(stage) do
      render(conn, "stage.json", stage: stage)
    end
  end

  @doc """
  Deletes a pipe stage
  """
  operation(:delete,
    summary: "Delete a pipe stage",
    description: "Delete an existing pipe stage",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the pipe stage", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.PipeStage.DeletedPipeStage},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => s_uuid}) do
    current_user = conn.assigns[:current_user]

    with %Stage{} = stage <- Stages.get_pipe_stage(current_user, s_uuid),
         {:ok, %Stage{} = stage} <- Stages.delete_pipe_stage(stage) do
      render(conn, "delete.json", stage: stage)
    end
  end
end
