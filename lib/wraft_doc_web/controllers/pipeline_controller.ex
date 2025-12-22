defmodule WraftDocWeb.Api.V1.PipelineController do
  @moduledoc """
  PipelineController module handles all the actions associated with
  Pipeline model.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "pipeline:manage",
    index: "pipeline:show",
    update: "pipeline:manage",
    show: "pipeline:show",
    delete: "pipeline:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Forms
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormPipeline
  alias WraftDoc.Pipelines
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDocWeb.Schemas

  tags(["Pipeline"])

  @doc """
  Creates a pipeline.
  """
  operation(:create,
    summary: "Create a pipeline",
    description: "Create pipeline API",
    request_body:
      {"Pipeline to be created", "application/json", Schemas.Pipeline.PipelineRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Pipeline.PipelineAndStages},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.create_pipeline(current_user, params),
         %Form{} = form <- Forms.get_form(current_user, pipeline.source_id),
         {:ok, %FormPipeline{}} <- Forms.create_form_pipeline(form, pipeline.id) do
      Typesense.create_document(pipeline)
      render(conn, "create.json", pipeline: pipeline)
    end
  end

  @doc """
  Pipeline index of current user's organisation.
  """
  operation(:index,
    summary: "Pipeline index of a organisation",
    description: "API to list pipelines of current user's organisation.",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Name"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Pipeline.PipelineIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: pipelines,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Pipelines.pipeline_index(current_user, params) do
      render(conn, "index.json",
        pipelines: pipelines,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Update a pipeline.
  """
  operation(:update,
    summary: "Update a pipeline",
    description: "API to update a pipeline.",
    parameters: [
      id: [in: :path, type: :string, description: "ID of pipeline", required: true]
    ],
    request_body:
      {"Pipeline to be updated", "application/json", Schemas.Pipeline.PipelineRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Pipeline.ShowPipeline},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.get_pipeline(current_user, p_uuid),
         %Pipeline{} = pipeline <- Pipelines.pipeline_update(pipeline, current_user, params) do
      Typesense.update_document(pipeline)
      render(conn, "show.json", pipeline: pipeline)
    end
  end

  @doc """
  Show a pipeline.
  """
  operation(:show,
    summary: "Show a pipeline",
    description: "API to show a pipeline.",
    parameters: [
      id: [in: :path, type: :string, description: "ID of pipeline", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Pipeline.ShowPipeline},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.show_pipeline(current_user, p_uuid) do
      render(conn, "show.json", pipeline: pipeline)
    end
  end

  @doc """
  Delete a pipeline.
  """
  operation(:delete,
    summary: "Pipeline delete",
    description: "API to delete a pipeline",
    parameters: [
      id: [in: :path, type: :string, description: "pipeline id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Pipeline.Pipeline},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.get_pipeline(current_user, uuid),
         {:ok, %Pipeline{}} <- Pipelines.delete_pipeline(pipeline) do
      Typesense.update_document(pipeline)
      render(conn, "pipeline.json", pipeline: pipeline)
    end
  end
end
