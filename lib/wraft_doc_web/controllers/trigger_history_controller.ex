defmodule WraftDocWeb.Api.V1.TriggerHistoryController do
  @moduledoc """
  TriggerHistoryController module handles all the actions associated with
  TriggerHistory model.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  # plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Pipeline, Document.Pipeline.TriggerHistory}

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

    with %Pipeline{} = pipeline <- Document.get_pipeline(current_user, p_uuid),
         {:ok, %TriggerHistory{} = trigger_history} <-
           Document.create_trigger_history(current_user, pipeline, data),
         {:ok, %Oban.Job{}} <- Document.create_pipeline_job(trigger_history) do
      render(conn, "create.json")
    end
  end

  @doc """
  Trigger history index of a pipeline.
  """
  # TODO - write tests
  swagger_path :index do
    get("/pipelines/{pipeline_id}/triggers")
    summary("Pipeline trigger index")
    description("API to get the list of trigger histories of a pipeline")

    parameters do
      pipeline_id(:path, :string, "pipeline id", required: true)
      page(:query, :string, "Page number")
    end

    response(200, "OK", Schema.ref(:TriggerHistoryIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"pipeline_id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Document.get_pipeline(current_user, p_uuid),
         %{
           entries: triggers,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.get_trigger_histories_of_a_pipeline(pipeline, params) do
      render(conn, "index.json",
        triggers: triggers,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
