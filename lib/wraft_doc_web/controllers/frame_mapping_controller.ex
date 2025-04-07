defmodule WraftDocWeb.Api.V1.FrameMappingController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  plug(WraftDocWeb.Plug.Authorized,
    create: "frame_mapping:manage",
    show: "frame_mapping:show",
    update: "frame_mapping:manage",
    check_frame_mapping: "frame_mapping:manage"
  )

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Frames.FrameMapping

  def swagger_definitions do
    %{
      FrameMappingResponse:
        swagger_schema do
          title("Wraft Frame mapping response")
          description("Frame mapping response body")

          properties do
            fame_id(:string, "Frame id")
            content_type_id(:string, "Content type id")
            mapping(Schema.ref(:Mapping))
          end

          example(%{
            frame_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            content_type_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            inserted_at: "2023-08-21T14:00:00Z",
            updated_at: "2023-08-21T14:00:00Z",
            mapping: [
              %{
                id: "e63d02aa-6ea6-4e10-87aa-61061e7557eb",
                destination: %{
                  name: "E_name",
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c"
                },
                source: %{
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c",
                  name: "Name"
                }
              }
            ]
          })
        end,
      Mapping:
        swagger_schema do
          title("Frame mapping")
          description("Mapping body")

          properties do
            mapping(
              :array,
              "Mapping body Example:
              `mapping: [{
                \"source\": {\"id\": \"234ccd8c-22bf-460f-b847-5b040350d99d\", \"name\": \"clientName\"},
                \"destination\": {\"id\": \"2cc1724d-6141-406f-8bd1-208eb2f321bb\", \"name\": \"Frame Title\"}
            }]`",
              required: true
            )
          end
        end,
      FrameMapping:
        swagger_schema do
          title("Wraft Frame mapping")
          description("Frame mapping body to create")

          properties do
            frame_id(:string, "Frame id", required: true)
            content_type_id(:string, "Content type id", required: true)
            mapping(Schema.ref(:Mapping))
          end

          example(%{
            content_type_id: "0043bde9-3903-4cb7-b898-cd4d7cbe99bb",
            frame_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
            mapping: [
              %{
                destination: %{
                  name: "E_name",
                  destination_id: "992c50b2-c586-449f-b298-78d59d8ab81c"
                },
                source: %{
                  id: "992c50b2-c586-449f-b298-78d59d8ab81c",
                  name: "Name"
                }
              }
            ]
          })
        end,
      FrameMappingCheckResponse:
        swagger_schema do
          title("Check frame mapping response")
          description("Check frame mapping response body")

          properties do
            is_frame_mapped(:boolean, "Is frame mapped")
          end

          example(%{
            is_frame_mapped: true
          })
        end
    }
  end

  @doc """
  Create a frame mapping.
  """
  swagger_path :create do
    post("/content_types/{c_type_id}/frames/{frame_id}/mapping")
    summary("Create wraft form mapping")
    description("Create wraft form mapping API")

    parameters do
      frame_id(:path, :string, "Frame id", required: true)
      c_type_id(:path, :string, "Content type id", required: true)

      mapping(:body, Schema.ref(:FrameMapping), "Frame mapping to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:FrameMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"frame_id" => frame_id, "c_type_id" => content_type_id} = params) do
    current_user = conn.assigns.current_user

    with %ContentType{} = _content_type <-
           ContentTypes.get_content_type(current_user, content_type_id),
         %Frame{} = _frame <- Frames.get_frame(frame_id, current_user),
         {:ok, %FrameMapping{} = frame_mapping} <-
           Frames.create_frame_mapping(Map.put(params, "content_type_id", content_type_id)) do
      render(conn, "create.json", frame_mapping: frame_mapping)
    end
  end

  @doc """
  Update a frame mapping.
  """
  swagger_path :show do
    get("/content_types/{c_type_id}/frames/{frame_id}/mapping/{mapping_id}")
    summary("Get a frame_mapping")
    description("get frame_mapping API")

    parameters do
      form_id(:path, :string, "Frame id", required: true)
      c_type_id(:path, :string, "Content type id", required: true)
      mapping_id(:path, :string, "frame_mapping id", required: true)
    end

    response(200, "Ok", Schema.ref(:FrameMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, params) do
    current_user = conn.assigns.current_user

    with %FrameMapping{} = frame_mapping <- Frames.get_frame_mapping(current_user, params) do
      render(conn, "show.json", frame_mapping: frame_mapping)
    end
  end

  swagger_path :update do
    put("/content_types/{c_type_id}/frames/{frame_id}/mapping/{mapping_id}")
    summary("Update a frame_mapping")
    description("Update frame_mapping API")

    parameters do
      frame_id(:path, :string, "Frame id", required: true)
      mapping_id(:path, :string, "frame_mapping id", required: true)
      c_type_id(:path, :string, "Content type id", required: true)

      mapping(
        :body,
        Schema.ref(:FrameMapping),
        "FrameMapping to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:FrameMappingResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  # TODO write test cases
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, params) do
    current_user = conn.assigns.current_user

    with %FrameMapping{} = frame_mapping <- Frames.get_frame_mapping(current_user, params),
         {:ok, %FrameMapping{} = frame_mapping} <-
           Frames.update_frame_mapping(frame_mapping, params) do
      render(conn, "show.json", frame_mapping: frame_mapping)
    end
  end

  @doc """
  Check if frame is mapped
  """
  swagger_path :check_frame_mapping do
    put("/content_types/{c_type_id}/check_frame_mapping")
    summary("Checks the frame mapping")
    description("API to check frame mapping")

    parameters do
      c_type_id(:path, :string, "Content type id", required: true)
    end

    response(200, "Ok", Schema.ref(:FrameMappingCheckResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec check_frame_mapping(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check_frame_mapping(conn, %{"c_type_id" => content_type_id}) do
    current_user = conn.assigns.current_user

    with content_type <- ContentTypes.get_content_type(current_user, content_type_id),
         :ok <- Frames.check_frame_mapping(content_type) do
      render(conn, "is_mapped?.json")
    end
  end
end
