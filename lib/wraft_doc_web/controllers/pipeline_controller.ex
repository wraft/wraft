defmodule WraftDocWeb.Api.V1.PipelineController do
  @moduledoc """
  PipelineController module handles all the actions associated with
  Pipeline model.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Pipeline}

  def swagger_definitions do
    %{
      PipelineRequest:
        swagger_schema do
          title("Pipeline Request")
          description("Create pipeline request.")

          properties do
            name(:string, "Pipeline's name", required: true)
            api_route(:string, "Pipeline's API route", required: true)
            content_types(:list, "ID of Content types", required: true)
          end

          example(%{
            name: "Pipeline 1",
            api_route: "client.crm.com",
            content_types: ["23q23wejh38owje", "2347ksjbc98341"]
          })
        end,
      Pipeline:
        swagger_schema do
          title("Pipeline")
          description("Pipeline to generate multiple docs.")

          properties do
            id(:string, "ID of the pipeline")
            name(:string, "Name of the pipeline")
            api_route(:string, "API route of the CRM")
            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Pipeline 1",
            api_route: "client.crm.com",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      PipelineAndStages:
        swagger_schema do
          title("Pipeline and its stages")
          description("Show a pipeline and its stages.")

          properties do
            id(:string, "ID of the pipeline")
            name(:string, "Name of the pipeline")
            api_route(:string, "API route of the CRM")
            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
            stages(Schema.ref(:ContentTypeWithoutFields))
          end

          example(%{
            id: "1232148nb3478",
            name: "Pipeline 1",
            api_route: "client.crm.com",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            stages: [
              %{
                id: "1232148nb3478",
                name: "Offer letter",
                description: "An offer letter",
                prefix: "OFFLET",
                color: "#fffff",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ]
          })
        end,
      ShowPipeline:
        swagger_schema do
          title("Show pipeline")
          description("Show details of a pipeline")

          properties do
            id(:string, "ID of the pipeline")
            name(:string, "Name of the pipeline")
            api_route(:string, "API route of the CRM")
            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
            stages(Schema.ref(:ContentTypeWithoutFields))
            creator(Schema.ref(:User))
          end
        end,
      Pipelines:
        swagger_schema do
          title("Pipeline list")
          description("Pipelines created so far")
          type(:array)
          items(Schema.ref(:Pipeline))
        end,
      PipelineIndex:
        swagger_schema do
          properties do
            flows(Schema.ref(:Pipelines))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            pipelines: [
              %{
                id: "1232148nb3478",
                name: "Pipeline 1",
                api_route: "client.crm.com",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
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
  Creates a pipeline.
  """
  swagger_path :create do
    post("/pipelines")
    summary("Create a pipeline")
    description("Create pipeline API")

    parameters do
      pipeline(:body, Schema.ref(:PipelineRequest), "Pipeline to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:PipelineAndStages))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Document.create_pipeline(current_user, params) do
      conn |> render("create.json", pipeline: pipeline)
    end
  end

  @doc """
  Pipeline index of current user's organisation.
  """
  swagger_path :index do
    get("/pipelines")
    summary("Pipeline index of a organisation")
    description("API to list pipelines of current user's organisation.")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:PipelineIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: pipelines,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.pipeline_index(current_user, params) do
      conn
      |> render("index.json",
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
  swagger_path :update do
    put("/pipelines/{id}")
    summary("Update a pipeline")
    description("API to update a pipeline.")

    parameters do
      id(:path, :string, "ID of pipeline", required: true)
      pipeline(:body, Schema.ref(:PipelineRequest), "Pipeline to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowPipeline))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Document.get_pipeline(current_user, p_uuid),
         %Pipeline{} = pipeline <- Document.pipeline_update(pipeline, current_user, params) do
      conn
      |> render("show.json", pipeline: pipeline)
    end
  end
end
