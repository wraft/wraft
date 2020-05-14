defmodule WraftDocWeb.Api.V1.TriggerHistoryController do
  @moduledoc """
  TriggerHistoryController module handles all the actions associated with
  TriggerHistory model.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
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
      TriggerMeta:
        swagger_schema do
          title("Meta of trigger message")
          description("Meta of a trigger message")

          properties do
            meta(:map, "Meta of a trigger message", required: true)
          end

          example(%{meta: %{name: "John Doe", position: "HR Manager"}})
        end
    }
  end

  @doc """
  Create a trigger history.
  """
  swagger_path :create do
    post("/pipelines/{pipeline_id}/trigger")
    summary("Pipeline trigger")
    description("API to trigger a pipeline")

    parameters do
      pipeline_id(:path, :string, "pipeline id", required: true)
      meta(:body, Schema.ref(:TriggerMeta), "Meta of a trigger", required: true)
    end

    response(200, "OK", Schema.ref(:GeneralResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"pipeline_id" => p_uuid, "meta" => meta}) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Document.get_pipeline(current_user, p_uuid),
         {:ok, %TriggerHistory{} = trigger_history} <-
           Document.create_trigger_history(current_user, pipeline, meta),
         {:ok, %Oban.Job{}} <- Document.create_pipeline_job(trigger_history) do
      conn |> render("create.json")
    end
  end
end
