defmodule WraftDocWeb.Api.V1.TriggerHistoryController do
  @moduledoc """
  TriggerHistoryController module handles all the actions associated with
  TriggerHistory model.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "pipeline:manage",
    index: "pipeline:show",
    show: "pipeline:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Pipelines
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.TriggerHistories
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDocWeb.Schemas

  tags(["Trigger History"])

  @doc """
  Create a trigger history.
  """
  operation(:create,
    summary: "Pipeline trigger",
    description: "API to trigger a pipeline",
    parameters: [
      pipeline_id: [in: :path, type: :string, description: "pipeline id", required: true]
    ],
    request_body: {"Data of a trigger", "application/json", Schemas.TriggerHistory.TriggerData},
    responses: [
      ok: {"OK", "application/json", Schemas.TriggerHistory.GeneralResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"pipeline_id" => p_uuid, "data" => data}) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{id: pipeline_id} = pipeline <- Pipelines.get_pipeline(current_user, p_uuid),
         {:ok, %TriggerHistory{id: trigger_id} = trigger_history} <-
           TriggerHistories.create_trigger_history(current_user, pipeline, data),
         {:ok, %Oban.Job{}} <- TriggerHistories.create_pipeline_job(current_user, trigger_history) do
      render(conn, "create.json", trigger_id: trigger_id, pipeline_id: pipeline_id)
    end
  end

  @doc """
  Trigger history index of a pipeline.
  """
  # TODO - write tests
  operation(:index_by_pipeline,
    summary: "Pipeline trigger index",
    description: "API to get the list of trigger histories of a pipeline",
    parameters: [
      pipeline_id: [in: :path, type: :string, description: "pipeline id"],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.TriggerHistory.IndexResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec index_by_pipeline(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index_by_pipeline(conn, %{"pipeline_id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Pipelines.get_pipeline(current_user, p_uuid),
         %{
           entries: triggers,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- TriggerHistories.get_trigger_histories_of_a_pipeline(pipeline, params) do
      render(conn, "index.json",
        triggers: triggers,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Trigger history index.
  """
  operation(:index,
    summary: "Pipeline trigger history index",
    description: "API to get the list of trigger histories within an organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      pipeline_name: [in: :query, type: :string, description: "Pipeline Name"],
      status: [
        in: :query,
        type: :integer,
        description:
          "Allowed Status Codes => [enqued: 1, executing: 2, pending: 3, partially_completed: 4, success: 5, failed: 6]"
      ],
      sort: [
        in: :query,
        type: :string,
        description:
          "Sort Keys => pipeline_name, pipeline_name_desc, status, status_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.TriggerHistory.IndexResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  # TODO Add tests for this
  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: triggers,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- TriggerHistories.trigger_history_index(current_user, params) do
      render(conn, "index.json",
        triggers: triggers,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show a trigger history.
  """
  operation(:show,
    summary: "Show trigger history",
    description: "API to get a trigger history by ID",
    parameters: [
      id: [in: :path, type: :string, description: "Trigger History ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.TriggerHistory.Item},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %TriggerHistory{} = trigger_history <-
           TriggerHistories.get_trigger_history(current_user, id) do
      render(conn, "show.json", trigger_history: trigger_history)
    end
  end
end
