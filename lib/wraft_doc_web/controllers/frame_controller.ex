defmodule WraftDocWeb.Api.V1.FrameController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame

  def swagger_definitions do
    %{
      Frame:
        swagger_schema do
          title("Frame")
          description("A Frame resource")

          properties do
            id(:string, "Unique identifier for the frame", required: true)
            name(:string, "Name of the frame", required: true)
            type(:string, "Type of the frame", required: true)
            description(:string, "Description of the frame")
            inserted_at(:string, "Timestamp of frame creation", format: "ISO-8601")
            updated_at(:string, "Timestamp of last frame update", format: "ISO-8601")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "my-document-frame",
            description: "My document frame",
            type: "zip",
            inserted_at: "2024-01-15T10:30:00Z",
            updated_at: "2024-01-15T10:30:00Z"
          })
        end,
      UpdateFrame:
        swagger_schema do
          title("Update Frame")
          description("Updated Frame resource")

          properties do
            id(:string, "Unique identifier for the frame", required: true)
            name(:string, "Name of the frame", required: true)
            type(:string, "Type of the frame", required: true)
            description(:string, "Description of the frame")
            inserted_at(:string, "Timestamp of frame creation", format: "ISO-8601")
            updated_at(:string, "Timestamp of last frame update", format: "ISO-8601")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "my-document-frame",
            description: "My document frame",
            type: "zip",
            inserted_at: "2024-01-15T10:30:00Z",
            updated_at: "2024-01-15T10:30:00Z"
          })
        end,
      Frames:
        swagger_schema do
          title("All Frames")
          description("All frames created under current user's organisation")

          type(:array)
          items(Schema.ref(:UpdateFrame))
        end,
      ShowFrame:
        swagger_schema do
          title("Show Frame")
          description("Details of a specific frame")

          properties do
            frame(Schema.ref(:Frame))
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "my-document-frame",
            description: "My document frame",
            type: "typst",
            inserted_at: "2024-01-15T10:30:00Z",
            updated_at: "2024-01-15T10:30:00Z"
          })
        end,
      FrameIndex:
        swagger_schema do
          properties do
            frames(Schema.ref(:Frames))
            page_number(:integer, "Current page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of frame entries")
          end

          example(%{
            frames: [
              %{
                id: "123e4567-e89b-12d3-a456-426614174000",
                name: "my-document-frame",
                description: "My document frame",
                type: "typst",
                inserted_at: "2024-01-15T10:30:00Z",
                updated_at: "2024-01-15T10:30:00Z"
              }
            ],
            page_number: 1,
            total_pages: 5,
            total_entries: 25
          })
        end
    }
  end

  @doc """
  List frames for the current user's organisation
  """
  swagger_path :index do
    get("/frames")
    summary("Frame index")
    description("Frame index API")

    parameter(:page, :query, :string, "Page number")
    parameter(:name, :query, :string, "Frame Name")

    parameter(
      :sort,
      :query,
      :string,
      "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
    )

    response(200, "Ok", Schema.ref(:FrameIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: frames,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Frames.list_frames(current_user, params) do
      render(conn, "index.json",
        frames: frames,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Create a new frame
  """
  swagger_path :create do
    post("/frames")
    summary("Create a new frame")
    description("Create a new frame API")
    consumes("multipart/form-data")

    parameters do
      file(:formData, :file, "Frame file to upload")
      thumbnail(:formData, :file, "Frame thumbnail to upload")
    end

    response(200, "Created", Schema.ref(:Frame))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Frame{} = frame} <- Frames.create_frame(current_user, params) do
      render(conn, "create.json", frame: frame)
    end
  end

  @doc """
  Show a specific frame
  """
  swagger_path :show do
    get("/frames/{id}")
    summary("Show a frame")
    description("Show a frame API")

    parameters do
      id(:path, :string, "frame id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowFrame))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Frame{} = frame <- Frames.get_frame(id, current_user) do
      render(conn, "show.json", frame: frame)
    end
  end

  @doc """
  Delete a frame
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/frames/{id}")
    summary("Delete a frame")
    description("API to delete a frame")

    parameters do
      id(:path, :string, "frame id", required: true)
    end

    response(200, "Ok", Schema.ref(:Frame))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %Frame{} = frame <- Frames.get_frame(uuid, current_user),
         {:ok, %Frame{}} <- Frames.delete_frame(frame) do
      render(conn, "create.json", frame: frame)
    end
  end
end
