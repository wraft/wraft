defmodule WraftDocWeb.Api.V1.TriggerHistoryController do
  @moduledoc """
  TriggerHistoryController module handles all the actions associated with
  TriggerHistory model.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

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

  def swagger_definitions do
    %{
      GeneralResponse:
        swagger_schema do
          title("General response")
          description("Response for pipeline trigger and bulk jobs.")

          properties do
            info(:string, "Response message", required: true)
          end

          example(%{
            info: "Trigger accepted."
          })
        end,
      TriggerData:
        swagger_schema do
          title("Data of trigger message")
          description("Data of a trigger message")

          properties do
            data(:map, "Data of a trigger message", required: true)
          end

          example(%{data: %{name: "John Doe", position: "HR Manager"}})
        end,
      TriggerHistory:
        swagger_schema do
          title("A trigger history object")
          description("A trigger history object")

          properties do
            id(:string, "ID of the trigger history", required: true)
            data(:map, "Input data of the the trigger history", required: true)
            error(:map, "Error data of the the trigger history", required: true)
            state(:state, "State of the trigger history", required: true)
            start_time(:start_time, "Start time of the trigger history", required: true)
            end_time(:end_time, "End time of the trigger history", required: true)
            duration(:duration, "Duration of execution of the trigger history", required: true)
            zip_file(:zip_file, "Zip file of the trigger history", required: true)
            inserted_at(:string, "Trigger history created time", format: "ISO-8601")
            updated_at(:string, "Trigger history last updated time", format: "ISO-8601")
            user(Schema.ref(:User))
          end

          example(%{
            id: "jhdiuh23y498sjdbda",
            data: %{name: "John Doe"},
            error: %{},
            state: "success",
            start_time: "2020-01-21 14:00:00",
            end_time: "2020-01-21 14:12:00",
            duration: 720,
            zip_file: "builds-2020-01-21T14:11:58.565745Z.zip",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      TriggerHistories:
        swagger_schema do
          title("Trigger History list")
          description("Trigger histories created so far")
          type(:array)
          items(Schema.ref(:TriggerHistory))
        end,
      TriggerHistoryIndex:
        swagger_schema do
          properties do
            trigger_history(Schema.ref(:TriggerHistories))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            triggers: [
              %{
                id: "jhdiuh23y498sjdbda",
                data: %{name: "John Doe"},
                error: %{},
                state: "success",
                start_time: "2020-01-21 14:00:00",
                end_time: "2020-01-21 14:12:00",
                duration: 720,
                zip_file: "builds-2020-01-21T14:11:58.565745Z.zip",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z",
                creator: %{
                  id: "1232148nb3478",
                  name: "John Doe",
                  email: "email@xyz.com",
                  email_verify: true,
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  @doc """
  Create a trigger history.
  """
  swagger_path :create do
    post("/pipelines/{pipeline_id}/triggers")
    summary("Pipeline trigger")
    description("API to trigger a pipeline")

    parameters do
      pipeline_id(:path, :string, "pipeline id", required: true)
      data(:body, Schema.ref(:TriggerData), "Data of a trigger", required: true)
    end

    response(200, "OK", Schema.ref(:GeneralResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

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
  swagger_path :index_by_pipeline do
    get("/pipelines/{pipeline_id}/triggers")
    summary("Pipeline trigger index")
    description("API to get the list of trigger histories of a pipeline")

    parameters do
      pipeline_id(:path, :string, "pipeline id")
      page(:query, :string, "Page number")
    end

    response(200, "OK", Schema.ref(:TriggerHistoryIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

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
  swagger_path :index do
    get("/triggers")
    summary("Pipeline trigger history index")
    description("API to get the list of trigger histories within an organisation")

    parameters do
      page(:query, :string, "Page number")
      pipeline_name(:query, :string, "Pipeline Name")

      status(
        :query,
        :integer,
        "Allowed Status Codes => [enqued: 1, executing: 2, pending: 3, partially_completed: 4, success: 5, failed: 6]"
      )

      sort(
        :query,
        :string,
        "Sort Keys => pipeline_name, pipeline_name_desc, status, status_desc, inserted_at, inserted_at_desc"
      )
    end

    response(200, "OK", Schema.ref(:TriggerHistoryIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

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
  swagger_path :show do
    get("/triggers/{id}")
    summary("Show trigger history")
    description("API to get a trigger history by ID")

    parameters do
      id(:path, :string, "Trigger History ID", required: true)
    end

    response(200, "OK", Schema.ref(:TriggerHistory))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %TriggerHistory{} = trigger_history <-
           TriggerHistories.get_trigger_history(current_user, id) do
      render(conn, "show.json", trigger_history: trigger_history)
    end
  end
end
